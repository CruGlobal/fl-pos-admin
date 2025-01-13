require 'rails_helper'

describe PollSheet do
  self.use_transactional_tests = false

  # set global lightspeed import service
  ps = PollSheet.new

  it('it should initializecorrectly') do
    expect(ps.sheets).not_to be_nil
  end

  it('it should create a job') do
    job = ps.create_job
    expect(job.type).to eq('POLL_SHEET')
  end

  xit('it should poll sheets and find a tab that is ready to process') do
    # This test only runs successfully if there is a row that has 'Status' and 'READY FOR WOO IMPORT' as the values of the first two cells
    vals = ps.get_ready_sheets
    puts "VALS: #{vals[0]}"
  end

end
