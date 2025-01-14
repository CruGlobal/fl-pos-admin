class SheetTabNamesService
  SHEET_ID = ENV["GOOGLE_SHEET_ID"]
  SHEETS_SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS

  def self.get_tab_names
    @sheets = Google::Apis::SheetsV4::SheetsService.new
    @sheets.authorization = Google::Auth::ServiceAccountCredentials.make_creds(scope: SHEETS_SCOPE)
    response = @sheets.get_spreadsheet(SHEET_ID)
    response.sheets.map { |s| s.properties.title }
  end
end
