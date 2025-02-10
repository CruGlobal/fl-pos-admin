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
      "calcDiscount",
      "Customer",
      "SaleLines",
      "ShipTo",
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
          "discountAmount",
          "discountPercent",
          "isSpecialOrder",
          "calcTotal",
          "calcSubtotal",
          "calcLineDiscount",
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
      "ShipTo" => {
        "arrayable" => false,
        "root" => [
          "shipToID",
          "shipped",
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
            "arrayable" => false,
            "root" => [
              "ContactAddress"
            ],
            "ContactAddress" => {
              "arrayable" => true,
              "root" => [
                "address1",
                "city",
                "state",
                "zip"
              ]
            }
          },
          "Phones" => {
            "arrayable" => false,
            "root" => [
              "ContactPhone"
            ],
            "ContactPhone" => {
              "arrayable" => true,
              "root" => [
                "number",
                "useType"
              ]
            }
          },
          "Emails" => {
            "arrayable" => false,
            "root" => [
              "ContactEmail"
            ],
            "ContactEmail" => {
              "arrayable" => true,
              "root" => [
                "address",
                "useType"
              ]
            }
          }
        }
      },
      "Contact" => {
        "arrayable" => false,
        "root" => [
          "Addresses",
          "Phones",
          "Emails"
        ],
        "Addresses" => {
          "arrayable" => false,
          "root" => [
            "ContactAddress"
          ],
          "ContactAddress" => {
            "arrayable" => true,
            "root" => [
              "address1",
              "city",
              "state",
              "zip"
            ]
          }
        },
        "Phones" => {
          "arrayable" => false,
          "root" => [
            "ContactPhone"
          ],
          "ContactPhone" => {
            "arrayable" => true,
            "root" => [
              "number",
              "useType"
            ]
          }
        },
        "Emails" => {
          "arrayable" => false,
          "root" => [
            "ContactEmail"
          ],
          "ContactEmail" => {
            "arrayable" => true,
            "root" => [
              "address",
              "useType"
            ]
          }
        }
      }
    },
    "ShipTo" => {
      "arrayable" => false,
      "root" => [
        "Contact"
      ],
      "Contact" => {
        "arrayable" => false,
        "root" => [
          "Addresses",
        ],
        "Addresses" => {
          "arrayable" => false,
          "root" => [
            "ContactAddress"
          ],
          "ContactAddress" => {
            "arrayable" => true,
            "root" => [
              "address1",
              "city",
              "state",
              "zip"
            ]
          }
        },
      }
    }
  }.freeze

  def self.fields_to_keep
    @fields_to_keep
  end
end
