require 'rails_helper'

describe WooImport do
  self.use_transactional_tests = false

  # set global lightspeed import service
  wi = WooImport.new

  it('it should initializecorrectly') do
    expect(wi.woo).not_to be_nil
    expect(wi.sheets).not_to be_nil
    expect(wi.products).not_to be_nil
  end

  it('it should get an array of objects from the sheet') do
    job = wi.create_job
    job.event_code = 'WTR25CHS1'
    rows = wi.get_spreadsheet job
    puts "ROWS: #{rows.inspect}"
  end

end
