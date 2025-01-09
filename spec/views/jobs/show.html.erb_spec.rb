require 'rails_helper'

RSpec.describe "jobs/show", type: :view do
  before(:each) do
    assign(:job, Job.create!())
  end

  it "renders attributes in <p>" do
    render
  end
end
