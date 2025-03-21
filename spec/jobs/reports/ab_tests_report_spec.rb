require 'rails_helper'

RSpec.describe Reports::AbTestsReport do
  subject(:job) { described_class.new(report_date) }
  let(:report_date) { Date.new(2023, 12, 25) }
  let(:email) { 'email@example.com' }
  let(:tested_percent) { 1 }
  let(:queries) do
    [
      {
        title: 'Sign in success rate by CAPTCHA validation performed',
        query: <<~QUERY,
          fields properties.event_properties.captcha_validation_performed as `Captcha Validation Performed`
          | filter name = 'Email and Password Authentication'
          | stats avg(properties.event_properties.success)*100 as `Success Percent` by `Captcha Validation Performed`
          | sort `Captcha Validation Performed` asc
        QUERY
        row_labels: ['Validation Not Performed', 'Validation Performed'],
      },
    ]
  end
  let(:ab_tests) do
    {
      RECAPTCHA_SIGN_IN: AbTest.new(
        experiment_name: 'reCAPTCHA at Sign-In',
        persist: true,
        max_participants: 10_000,
        buckets: { sign_in_recaptcha: tested_percent },
        report: { email:, queries: },
      ),
      UNREPORTED_EXPERIMENT: AbTest.new(
        experiment_name: 'Unreported Experiment',
        buckets: { group_a: 1 },
      ),
    }
  end

  before do
    allow(AbTests).to receive(:all).and_return(ab_tests)
  end

  describe '#perform' do
    let(:emailable_reports) do
      [
        Reporting::EmailableReport.new(
          title: 'Sign in success rate by CAPTCHA validation performed',
          table: [
            ['Captcha Validation Performed', 'Success Percent'],
            ['Validation Not Performed', '90.19%'],
            ['Validation Performed', '85.68%'],
          ],
        ),
      ]
    end

    let(:report) do
      double(
        Reporting::AbTestsReport,
        as_emailable_reports: emailable_reports,
        participants_message: 'Total participants: 0 (of 10,000 maximum)',
      )
    end

    before do
      allow(Reporting::AbTestsReport).to receive(:new).with(
        ab_test: ab_tests[:RECAPTCHA_SIGN_IN],
        time_range: report_date.yesterday..report_date,
      ).and_return(report)

      allow(ReportMailer).to receive(:tables_report).and_call_original
    end

    it 'emails the table report with csv' do
      expect(ReportMailer).to receive(:tables_report).with(
        email:,
        subject: "A/B Tests Report - reCAPTCHA at Sign-In - #{report_date}",
        message: [
          "A/B Tests Report - reCAPTCHA at Sign-In - #{report_date}",
          'Total participants: 0 (of 10,000 maximum)',
        ],
        reports: emailable_reports,
        attachment_format: :csv,
      )

      job.perform(report_date)
    end

    context 'when associated report email is nil' do
      let(:email) { nil }

      it 'does not email the table report' do
        expect(ReportMailer).not_to receive(:tables_report)

        job.perform(report_date)
      end
    end

    context 'when a/b test buckets are zero (test is inactive)' do
      let(:tested_percent) { 0 }

      it 'does not email the table report' do
        expect(ReportMailer).not_to receive(:tables_report)

        job.perform(report_date)
      end
    end

    context 'when called on class' do
      it 'emails the table report' do
        expect(ReportMailer).to receive(:tables_report)

        described_class.perform_now(report_date)
      end
    end
  end
end
