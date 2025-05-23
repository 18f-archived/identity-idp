# frozen_string_literal: true

class DuplicateProfileChecker
  attr_reader :user, :user_session, :sp

  def initialize(user:, user_session:, sp:)
    @user = user
    @user_session = user_session
    @sp = sp
  end

  def check_for_duplicate_profiles
    return unless sp_eligible_for_one_account?
    return unless user_has_ial2_profile?
    cacher = Pii::Cacher.new(user, user_session)
    profile_id = user&.active_profile&.id
    pii = cacher.fetch(profile_id)
    duplicate_ssn_finder = Idv::DuplicateSsnFinder.new(user:, ssn: pii[:ssn])
    associated_profiles = duplicate_ssn_finder.associated_facial_match_profiles_with_ssn
    if !duplicate_ssn_finder.ial2_profile_ssn_is_unique?
      confirmation = DuplicateProfileConfirmation.find_by(profile_id:)
      if confirmation
        if !(confirmation.duplicate_profile_ids == associated_profiles.map(&:id))
          confirmation.update(
            confirmed_at: Time.zone.now,
            confirmed_all: false,
            duplicate_profile_ids: associated_profiles.map(&:id),
          )
        end
      else
        DuplicateProfileConfirmation.create(
          profile_id: profile_id,
          confirmed_at: Time.zone.now,
          duplicate_profile_ids: associated_profiles.map(&:id),
        )
      end
    end
  end

  private

  def sp_eligible_for_one_account?
    return false unless sp.present?
    IdentityConfig.store.eligible_one_account_providers.include?(sp&.issuer)
  end

  def user_has_ial2_profile?
    user.identity_verified_with_facial_match?
  end
end
