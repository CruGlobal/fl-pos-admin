class GoogleSheetsController < ApplicationController
  def index
    @google_sheet_tab_names = get_sheet_tab_names
  end

  def import
    tab_name = params[:tab_name]

    # TODO: Implement Google Sheets API to import data from the selected tab

    redirect_to google_sheets_path, notice: "Data import from #{tab_name} started"
  end

  private

  def get_sheet_tab_names
    # TODO: Implement Google Sheets API to get the tab names
    ["placeholder_tab_name_1", "placeholder_tab_name_2"]
  end
end
