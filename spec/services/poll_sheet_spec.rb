require "rails_helper"

describe PollSheet do
  self.use_transactional_tests = false

  before do
    # set global lightspeed import service
    PollSheet.new
  end

  xit("it should initializecorrectly") do
    expect(ps.sheets).not_to be_nil
  end

  xit("it should create a job") do
    job = ps.create_job
    expect(job.type).to eq("POLL_SHEET")
  end

  xit("it should poll sheets and find a tab that is ready to process") do
    # This test only runs successfully if there is a row that has 'Status' and 'READY FOR WOO IMPORT' as the values of the first two cells
    vals = ps.get_ready_sheets
    puts "VALS: #{vals[0]}"
  end

  xit("should be able to set the ready status of a sheet") do
    ps.set_ready_status("WTR25CHS1", 21, "ERROR")
    response = @sheets.get_spreadsheet(SHEET_ID)
    response.sheets.select do |s|
      if s.properties.title == "WTR25CHS1"
        range = "WTR25CHS1!A21:B"
        response = @sheets.get_spreadsheet_values(SHEET_ID, range, value_render_option: "UNFORMATTED_VALUE")
        values = response.values
        expect(values[0][1]).to eq("ERROR")
      end
    end
  end
end
