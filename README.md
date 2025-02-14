## POS Admin Technical Guide

Welcome to the POS Admin developer guide! This document was written so that rails developers who work for Cru can easily get up to speed developing inside the POS Admin project.


## Background

One of the primary products of the FamilyLife ministry is the Weekend to Remember getaway event for couples. Many of these events happen throughout the year, and hundreds of couples attend each event in efforts to strengthen their marriage.


### Factual Basis



* At each event, various products and educational materials are sold by FamilyLife staff and volunteers.
* The primary system of record for FamilyLife sales data is WooCommerce.
* The Point of Sale (POS) system used to sell materials is called [Lightspeed](https://www.lightspeedhq.com/login/) (Retail POS R-Series). It is unrelated to WooCommerce, and no known plugin exists as of this writing. Lightspeed is a SaaS product.
* The inventory system that instructs the warehouse about how many products are sold and which ones to replenish is accessed through SalesForce.


### Need for a Solution

So then, if sales are made in Lightspeed POS, and WooCommerce and SalesForce are separate systems, how does this data flow from Lightspeed into WooCommerce and SalesForce?


## Solution Description

A custom app was developed that uses the Lightspeed API to read sales data for each weekend event, and write that data to two targets:



1. The Product_Sale__c object in the FamilyLife instance of SalesForce. \

2. A Google Sheet that contains all necessary information to construct sales in WooCommerce.


## Responsible Parties


### Developers

This app is managed by Server Application Engineering. At the time of this writing, the SAE team is led by Lee Braddock. It was originally developed by Jon Watson and Justin Sabelko, completed in February of 2025.


### Product Owner

Mona Horton owns the product and business rules, and serves as the business interface between FamilyLife Staff and USTECH.


### Subject Matter Experts



* **Lightspeed Operators:** Deb Gulbranson and Sherri Oehme work with various other staff and volunteers to keep the Lightspeed product properly configured for each event.
* **Process Admins:** Chad Donley and Patrick Jones are responsible for using the POS Admin tool and insuring the quality of data as it flows into SalesForce and WooCommerce respectively.
* **SalesForce Admin:** Tim Jones is responsible for the sales inventory processing after the sales inventory report has been written to SalesForce.


## Business Process

Chad Donley is responsible for starting the process once an event over the previous weekend has occurred. Chad starts this process by logging into the POS Admin tool and creating a new “job” in the POS Admin tool. This act does two things: \




1. Creates a new “SF Import” job. This job will extract sale inventory data from Lightspeed and write it to the Product_Sale__c object in SalesForce. Once this job is created, no human intervention is required. \

2. Creates a new “LS Export” job. This job will extract all sale line data for a particular event from Lightspeed and write it to a new tab in a designated Google Sheet.

Once Chad’s part is done, Patrick Jones looks over the sheet for data integrity issues and ensures that the data is ready to be imported into WooCommerce. When Patrick is done, he changes a single “Status” field in the sheet from “IN REVIEW” to “READY FOR WOO IMPORT”.

The POS Admin product looks at all tabs in this sheet every 30 minutes to see if any new sheets are ready to be processed. If it finds a sheet that is marked as ready, it will import it into WooCommerce.


## Technology Stack


<table>
  <tr>
   <td><strong>Concern</strong>
   </td>
   <td><strong>Technology Used</strong>
   </td>
  </tr>
  <tr>
   <td><strong>Source Control</strong>
   </td>
   <td>Github (<a href="https://github.com/CruGlobal/fl-pos-admin">fl-pos-admin</a>)
   </td>
  </tr>
  <tr>
   <td><strong>Code Framework</strong>
   </td>
   <td>Ruby on Rails (rails version 8)
   </td>
  </tr>
  <tr>
   <td><strong>Caching</strong>
   </td>
   <td>SolidCache
   </td>
  </tr>
  <tr>
   <td><strong>Job Handler</strong>
   </td>
   <td>Sidekiq
   </td>
  </tr>
  <tr>
   <td><strong>Asset Pipeline</strong>
   </td>
   <td>Propshaft
   </td>
  </tr>
  <tr>
   <td><strong>End-to-End JS Integration</strong>
   </td>
   <td>turbo
   </td>
  </tr>
  <tr>
   <td><strong>CSS Framework</strong>
   </td>
   <td>Bootstrap 5
   </td>
  </tr>
  <tr>
   <td><strong>Secrets</strong>
   </td>
   <td>AWS secrets accessed as environment variables
   </td>
  </tr>
  <tr>
   <td><strong>Database</strong>
   </td>
   <td>Postgres
   </td>
  </tr>
  <tr>
   <td><strong>Integrations</strong>
   </td>
   <td>
<ul>

<li>Lightspeed API (gem: marketplacer/lightspeed_pos)</li>

<li>SalesForce (gem: salesforce_bulk_api)</li>

<li>Woo Commerce (gem: woocommerce_api)</li>
</ul>
   </td>
  </tr>
  <tr>
   <td><strong>Server Configuration</strong>
   </td>
   <td>Terraform
   </td>
  </tr>
</table>



## Integration Management


### SalesForce

The SalesForce integration requires the following, and is managed by Tim Jones.


<table>
  <tr>
   <td><strong>Secret Name</strong>
   </td>
   <td><strong>Description</strong>
   </td>
  </tr>
  <tr>
   <td><strong>SF_INSTANCE_URL</strong>
   </td>
   <td>SalesForce URL for the FamilyLife Tenant in SalesForce.
   </td>
  </tr>
  <tr>
   <td><strong>SF_HOST</strong>
   </td>
   <td>The FQDN from the SF_INSTANCE_URL
   </td>
  </tr>
  <tr>
   <td><strong>SF_LOGIN_URL</strong>
   </td>
   <td>The SalesForce login URL. Must be included even if it is the same as the SF_INSTANCE_URL.
   </td>
  </tr>
  <tr>
   <td><strong>SF_PASSWORD</strong>
   </td>
   <td>The service account user’s password that will be logging in.
   </td>
  </tr>
  <tr>
   <td><strong>SF_TOKEN</strong>
   </td>
   <td>The service account user’s API login token that will be added to the end of the password.
   </td>
  </tr>
  <tr>
   <td><strong>SF_USERNAME</strong>
   </td>
   <td>The service account’s user name.
   </td>
  </tr>
  <tr>
   <td><strong>SF_VERSION</strong>
   </td>
   <td>The version of the SalesForce API to use. Version 58.0 was used originally.
   </td>
  </tr>
  <tr>
   <td><strong>SF_CLIENT_ID</strong>
   </td>
   <td>The Client ID for the API connection.
   </td>
  </tr>
  <tr>
   <td><strong>SF_CLIENT_SECRET</strong>
   </td>
   <td>The Client Secret for the API connection.
   </td>
  </tr>
</table>


The SalesForce connection tends to be very straight forward from a developer perspective. The SalesForce team manages credentials for API access. If you need specific access, Tim Jones is your contact.


### Lightspeed API

Lightspeed has a custom REST API implementation that has some notable restrictions: \




* API Tokens are provided on a per-user basis. \

* API Tokens must be registered through a [special process](https://developers.lightspeedhq.com/retail/authentication/clients/) involving an obscure form used to request a new client on a per-user basis. Each Client configuration must belong to a unique email address. \
  \
  **IMPORTANT:** Read the above linked instructions carefully. This process will result in a Client ID and Secret that will then allow you to generate access tokens through an OAuth web interface. \

* Therefore, the process of acquiring a new token must be integrated into a web-based application, and **cannot be automated using a headless server environment**.


## Dev Process and Environments

Each environment should have its own Lightspeed API Client credentials. Follow the instructions above if you are setting up a local development environment.


### Process



1. Clone the project from the repository linked in the Technology Stack description above.
2. Contact a fellow developer to get a copy of their .env.local file and copy it to your project work area.
3. Create a new Postgres database accessible locally on your computer and configure the name of that database to correspond to the names expected by the project configuration.
4. Record your database configuration variables in your local copy of .env.local AND .env.test.local (so your unit tests will work).
5. Do `bundle install`, `bin/rails css:install:bootstrap`, and `bin/dev`, and you should be cooking with gas.
6. For help getting your development work area set up, contact Justin Sabelko.


### Environments



* **Production:** [https://fl-pos-admin.cru.org/](https://fl-pos-admin.cru.org/)
* **Stage:** [https://fl-pos-admin-stage.cru.org/](https://fl-pos-admin-stage.cru.org/)
