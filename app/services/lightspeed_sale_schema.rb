class LightspeedSaleSchema
  @fields_to_keep = {
    "arrayable" => false,
    "root" => [
      "saleID",
      "timeStamp",
      "completed",
      "voided",
      "calcTotal",
      "calcSubtotal",
      "Customer",
      "SaleLines",
      "calcTax1",
      "calcTax2",
      "shipToID"
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
          "unitPrice",
          "displayableSubtotal",
          "isSpecialOrder",
          "calcTotal",
          "calcTax1",
          "calcTax2",
          "tax",
          "Item"
        ],
        "Item" => {
          "arrayable" => false,
          "root" => [
            "customSku"
          ]
        }
      }
    },
    "SalePayments" => {
      "arrayable" => false,
      "root" => [
        "SalePayment"
      ],
      "SalePayment" => {
        "arrayable" => true,
        "root" => [
          "amount"
        ]
      }
    },
    "Customer" => {
      "arrayable" => false,
      "root" => [
        "firstName",
        "lastName",
        "Contact"
      ],
      "Contact" => {
        "arrayable" => false,
        "root" => [
          "Addresses",
          "Phones",
          "Emails"
        ],
        "Addresses" => {
          "arrayable" => true,
          "root" => [
            "ContactAddress"
          ],
          "ContactAddress" => {
            "arrayable" => false,
            "root" => [
              "address1",
              "city",
              "state",
              "zip"
            ]
          }
        },
        "Phones" => {
          "arrayable" => true,
          "root" => [
            "number",
            "useType"
          ]
        },
        "Emails" => {
          "arrayable" => true,
          "root" => [
            "ContactEmail"
          ],
          "ContactEmail" => {
            "arrayable" => false,
            "root" => [
              "address",
              "useType"
            ]
          }
        }
      }
    }
  }.freeze

  def self.fields_to_keep
    @fields_to_keep
  end
end
