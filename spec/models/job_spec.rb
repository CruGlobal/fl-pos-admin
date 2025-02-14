require "rails_helper"

RSpec.describe Job, type: :model do
  context "#restart_job" do
    let(:job) { create(:job) }

    it "restarts the job" do
      expect(job.restart_job).to be_truthy
    end

    it "returns false for an invalid job type" do
      job.type = "INVALID"
      expect(job.restart_job).to be_falsey
    end

    it "updates the job status to created" do
      job.update(status: :processing)
      job.restart_job
      expect(job.status).to eq("created")
    end

    it "enqueues the correct job" do
      job.update(type: "WOO_IMPORT")
      expect { job.restart_job }.to have_enqueued_job(WoocommerceImportJob)

      job.update(type: "LS_EXTRACT")
      expect { job.restart_job }.to have_enqueued_job(LightspeedExtractJob)

      job.update(type: "SF_IMPORT")
      expect { job.restart_job }.to have_enqueued_job(SalesforceImportJob)

      job.update(type: "WOO_REFRESH")
      expect { job.restart_job }.to have_enqueued_job(WoocommerceRefreshJob)

      job.update(type: "POLL_SHEET")
      expect { job.restart_job }.to have_enqueued_job(PollSheetJob)
    end
  end
end
