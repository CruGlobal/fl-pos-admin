require "rails_helper"

describe PollSheet do
  self.use_transactional_tests = false

  let(:ps) { PollSheet.new }

  before do
    allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(true)
  end

  it("it should initialize correctly") do
    expect(ps.sheets).not_to be_nil
  end

  it("it should create a job") do
    job = ps.create_job
    expect(job.type).to eq("POLL_SHEET")
  end

  it("it should poll sheets and find a tab that is ready to process") do
    spreadsheet = double("spreadsheet", sheets: [Google::Apis::SheetsV4::Sheet.new(properties: double("properties", title: "WTR25CHS1"))])
    allow_any_instance_of(Google::Apis::SheetsV4::SheetsService).to receive(:get_spreadsheet).and_return(spreadsheet)
    allow_any_instance_of(Google::Apis::SheetsV4::SheetsService).to receive(:get_spreadsheet_values).and_return(Google::Apis::SheetsV4::ValueRange.new(values: [["Status", "READY FOR WOO IMPORT"]]))

    vals = ps.get_ready_sheets
    puts "VALS: #{vals[0]}"
  end
end
