# frozen_string_literal: true

require 'rails_helper'

class UxDumper
  let(:slides) { [] }

  SCREENSHOT_DIR = 'screenshots'

  def initialize(name)
    @name = name
  end

  def file_basename(page)
    parsed_url = URI(page.driver.current_url)
    Pathname.new("#{SCREENSHOT_DIR}#{parsed_url.path}")
  end

  def screenshot_path
    Pathname.new("screenshots/slide-#{slides.length}.png")
  end

  def attach_events_to_last_slide
    if slides.empty?
      @events_before_first_screenshot = fake_analytics.events.dup
    else
      slides.last[:events] = fake_analytics.events.dup
    end
    fake_analytics.events.clear
  end

  def resize_to_show_everything(page)
    width = page.driver.execute_script(
      'return Math.max(' \
      '  document.body.scrollWidth,' \
      '  document.body.offsetWidth,' \
      '  document.documentElement.clientWidth,' \
      '  document.documentElement.scrollWidth,' \
      '  document.documentElement.offsetWidth' \
      ');',
    )
    height = page.driver.execute_script(
      'return Math.max(' \
      '  document.body.scrollHeight,' \
      '  document.body.offsetHeight,' \
      '  document.documentElement.clientHeight,' \
      '  document.documentElement.scrollHeight,' \
      '  document.documentElement.offsetHeight' \
      ');',
    )

    page.driver.resize_window_to(page.driver.current_window_handle, width, height)
  end

  def take_screenshot(page)
    attach_events_to_last_slide

    resize_to_show_everything(page)
    FileUtils.mkdir_p(screenshot_path.dirname)
    page.driver.browser.save_screenshot(screenshot_path)

    slides << { path: page.current_path, image: screenshot_path, links: links_out_of(page) }
  end

  def links_out_of(page)
    links = page.all(:css, 'a').map { |link| link['href'] }
    forms = page.all(:css, 'form').map { |form| form['action'] }
    (links + forms).
      reject { |url| URI(url).scheme == 'https' }.
      map { |url| URI(url).path }.
      sort.
      uniq
  end

  def dump_path(slide)
    "## #{slide[:path]}"
  end

  def dump_image(slide)
    "![#{slide[:path]}](#{slide[:image]})"
  end

  def dump_links(slide)
    "#### links\n\n" +
      (slide[:links]&.map { |link| "- `#{link}`" }&.join("\n") || '') +
      "\n\n"
  end

  def dump_events(slide)
    "#### events\n\n" \
    "<table>\n" \
    "<tr><th>Event</th><th>Parameters</th></tr>\n" +
      (slide[:events]&.map { |key, value|
         "<tr><td>#{key}</td><td>#{value}</td></tr>"
       }&.join("\n") || '') +
      "\n" \
      "</table>\n\n"
  end

  after do
    attach_events_to_last_slide

    File.open('ferd.md', 'w') do |f|
      f.puts
      slides.each do |slide|
        f.puts dump_path(slide)
        f.puts dump_image(slide)
        f.puts dump_links(slide)
        f.puts dump_events(slide)
        f.puts '---'
      end
      f.puts
    end
  end
end

RSpec.feature 'document capture step', :js, allowed_extra_analytics: [:*] do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper
  include ActionView::Helpers::DateHelper

  let(:max_attempts) { IdentityConfig.store.doc_auth_max_attempts }
  let(:fake_analytics) { FakeAnalytics.new }

  before(:each) do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ServiceProviderSession).to receive(:sp_name).and_return(@sp_name)
  end

  after(:each) do
    fake_analytics.events.each do |k, v|
      puts "  #{k}: #{v}"
    end
    puts
  end

  before(:all) do
    @user = user_with_2fa
    @sp_name = 'Test SP'
  end

  after(:all) do
    @user.destroy
    @sp_name = ''
  end

  context 'selfie check' do
    let(:selfie_check_enabled) { true }

    before do
      allow(IdentityConfig.store).to receive(:use_vot_in_sp_requests).and_return(true)
    end

    context 'when a selfie is required by the SP' do
      context 'on mobile platform', allow_browser_log: true do
        before do
          # mock mobile device as cameraCapable, this allows us to process
          allow_any_instance_of(ActionController::Parameters).
            to receive(:[]).and_wrap_original do |impl, param_name|
            param_name.to_sym == :skip_hybrid_handoff ? '' : impl.call(param_name)
          end

          @events_before_first_screenshot = {}
        end

        context 'with a passing selfie' do
          it 'proceeds to the next page with valid info, including a selfie image' do
            perform_in_browser(:mobile) do
              visit_idp_from_oidc_sp_with_ial2(biometric_comparison_required: true)
              sign_in_and_2fa_user(@user)

              take_screenshot(page)

              complete_doc_auth_steps_before_document_capture_step

              take_screenshot(page)

              attach_liveness_images

              take_screenshot(page)

              submit_images

              take_screenshot(page)

              fill_out_ssn_form_ok

              take_screenshot(page)

              click_idv_continue

              take_screenshot(page)

              complete_verify_step

              take_screenshot(page)
            end
          end
        end
      end
    end
  end
end
