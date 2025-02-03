require "rails_helper"

RSpec.describe LightspeedExtractJob, type: :job do
  it "queues the job" do
    expect {
      LightspeedExtractJob.perform_later
    }.to have_enqueued_job
  end

  it "executes perform" do
    stub_request(:get, "https://api.merchantos.com/API/Account.json?limit=100&load_relations=all&offset=0").to_return(status: 200, body: "", headers: {})
    expect_any_instance_of(LSExtract).to receive(:poll_jobs)
    LightspeedExtractJob.perform_now
  end
end
