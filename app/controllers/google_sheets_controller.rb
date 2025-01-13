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
    SheetTabNamesService.get_tab_names
  end
end
