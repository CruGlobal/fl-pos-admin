class LightspeedInventorySchema
  @fields_to_keep = {
    "arrayable" => false,
    "root" => [
      "saleID",
      "Customer",
      "SaleLines"
    ],
    "SaleLines" => {
      "arrayable" => false,
      "root" => [
        "SaleLine"
      ],
      "SaleLine" => {
        "arrayable" => true,
        "root" => [
          "unitQuantity",
          "Item"
        ],
        "Item" => {
          "arrayable" => false,
          "root" => [
            "customSku"
          ]
        }
      }
    }
  }.freeze

  def self.fields_to_keep
    @fields_to_keep
  end
end
