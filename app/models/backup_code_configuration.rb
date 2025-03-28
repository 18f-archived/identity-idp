# frozen_string_literal: true

class BackupCodeConfiguration < ApplicationRecord
  NUM_WORDS = 3

  include BackupCodeEncryptedAttributeOverrides

  belongs_to :user

  def self.unused
    where(used_at: nil)
  end

  def mfa_enabled?
    persisted? && used_at.nil?
  end

  def selection_presenters
    [TwoFactorAuthentication::SignInBackupCodeSelectionPresenter.new(user:, configuration: self)]
  end

  def friendly_name
    :backup_codes
  end

  def self.selection_presenters(set)
    if set.any?
      set.first.selection_presenters
    else
      []
    end
  end

  class << self
    def find_with_code(code:, user_id:)
      return if code.blank?
      code = RandomPhrase.normalize(code)
      user_salted_fingerprints = self.salted_fingerprints(code: code, user_id: user_id)

      where(salted_code_fingerprint: user_salted_fingerprints).find_by(user_id: user_id)
    end

    def salted_fingerprints(code:, user_id:)
      user_salt_costs = select(:code_salt, :code_cost)
        .distinct
        .where(user_id: user_id)
        .where.not(code_salt: nil).where.not(code_cost: nil)
        .pluck(:code_salt, :code_cost)

      user_salt_costs.map do |salt, cost|
        scrypt_password_digest(password: code, salt: salt, cost: cost)
      end
    end

    def scrypt_password_digest(password:, salt:, cost:)
      scrypt_salt = cost + OpenSSL::Digest::SHA256.hexdigest(salt)
      scrypted = SCrypt::Engine.hash_secret password, scrypt_salt, 32
      SCrypt::Password.new(scrypted).digest
    end
  end
end
