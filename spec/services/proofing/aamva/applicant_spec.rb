require 'rails_helper'

RSpec.describe Proofing::Aamva::Applicant do
  let(:proofer_applicant) do
    {
      uuid: '1234-4567-abcd-efgh',
      first_name: 'Testy',
      last_name: 'McTesterson',
      dob: '10/29/1942',
      state_id_number: '123-456-789',
      state_id_jurisdiction: 'VA',
      id_doc_type: 'drivers_license',
    }
  end

  describe '.from_proofer_applicant(applicant)' do
    it 'should create an AAMVA applicant with necessary proofer applicant data' do
      aamva_applicant = described_class.from_proofer_applicant(proofer_applicant)

      expect(aamva_applicant.uuid).to eq(proofer_applicant[:uuid])
      expect(aamva_applicant.first_name).to eq(proofer_applicant[:first_name])
      expect(aamva_applicant.last_name).to eq(proofer_applicant[:last_name])
      expect(aamva_applicant.dob).to eq('1942-10-29')
      expect(aamva_applicant.state_id_data.state_id_number).to eq(
        proofer_applicant[:state_id_number].gsub(/[^\w\d]/, ''),
      )
      expect(aamva_applicant.state_id_data.state_id_jurisdiction).to eq(
        proofer_applicant[:state_id_jurisdiction],
      )
      expect(aamva_applicant.state_id_data.id_doc_type).to eq(proofer_applicant[:id_doc_type])
    end
  end

  it 'should format dob into CCYY-MM-DD form' do
    proofer_applicant[:dob] = '1942-10-29'
    aamva_applicant = Proofing::Aamva::Applicant.from_proofer_applicant(proofer_applicant)

    expect(aamva_applicant.dob).to eq('1942-10-29')

    proofer_applicant[:dob] = '10/29/1942'
    aamva_applicant = Proofing::Aamva::Applicant.from_proofer_applicant(proofer_applicant)

    expect(aamva_applicant[:dob]).to eq('1942-10-29')

    proofer_applicant[:dob] = '19421029'
    aamva_applicant = Proofing::Aamva::Applicant.from_proofer_applicant(proofer_applicant)

    expect(aamva_applicant[:dob]).to eq('1942-10-29')
  end

  it 'should format empty or malformed dobs into empty strings' do
    proofer_applicant[:dob] = ''
    aamva_applicant = Proofing::Aamva::Applicant.from_proofer_applicant(proofer_applicant)

    expect(aamva_applicant.dob).to eq('')

    proofer_applicant[:dob] = nil
    aamva_applicant = Proofing::Aamva::Applicant.from_proofer_applicant(proofer_applicant)

    expect(aamva_applicant[:dob]).to eq('')

    proofer_applicant[:dob] = '10/29/19422'
    aamva_applicant = Proofing::Aamva::Applicant.from_proofer_applicant(proofer_applicant)

    expect(aamva_applicant[:dob]).to eq('')
  end

  context 'when height includes inches >= 10' do
    it 'formats as expected' do
      proofer_applicant[:height] = 95
      aamva_applicant = Proofing::Aamva::Applicant.from_proofer_applicant(proofer_applicant)
      expect(aamva_applicant[:height]).to eq('711')
    end
  end

  context 'when height includes inches < 10' do
    it 'formats as expected' do
      proofer_applicant[:height] = 67
      aamva_applicant = Proofing::Aamva::Applicant.from_proofer_applicant(proofer_applicant)

      # From the DLDV user guide:
      # > Height data should be 3 characters (i.e. 5 foot 7 inches is submitted as 507)
      expect(aamva_applicant[:height]).to eq('507')
    end
  end
end
