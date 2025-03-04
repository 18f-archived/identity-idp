# frozen_string_literal: true

class SelectEmailForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  attr_reader :user, :identity, :selected_email_id

  validate :validate_owns_selected_email
  validates :selected_email_id, presence: {
    message: proc { I18n.t('simple_form.required.text') },
  }

  def initialize(user:, identity: nil)
    @user = user
    @identity = identity
  end

  def submit(params)
    @selected_email_id = params[:selected_email_id].try(:to_i) if !params[:selected_email_id].blank?

    success = valid?
    identity.update(email_address_id: selected_email_id) if success && identity

    FormResponse.new(
      success:,
      errors:,
      extra: extra_analytics_attributes,
    )
  end

  private

  def extra_analytics_attributes
    { selected_email_id: }
  end

  def validate_owns_selected_email
    return if user.confirmed_email_addresses.exists?(id: selected_email_id)
    errors.add(:selected_email_id, :not_found, message: t('email_address.not_found'))
  end
end
