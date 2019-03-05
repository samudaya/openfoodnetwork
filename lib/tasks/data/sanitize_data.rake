require 'highline'

namespace :ofn do
  namespace :data do
    desc 'Sanitize data'
    task sanitize: :environment do
      guard_and_warn

      Spree::User.update_all("email = concat(id, '_ofn_user@example.com'),
                              login = concat(id, '_ofn_user@example.com'),
                              unconfirmed_email = concat(id, '_ofn_user@example.com')")
      Spree::Customer.update_all("email = concat(id, '_ofn_customer@example.com'),
                                  name = concat('Customer Number ', id)")
      Spree::Order.update_all("email = concat(id, '_ofn_order@example.com')")
      Spree::Address.update_all("
        firstname = concat('Ms. Number', id), lastname = 'Jones',  phone = '01234567890',
        alternative_phone = '01234567890', address1 = 'Dummy address',
        address2 = 'Dummy address continuation', city = 'Dummy City', zipcode = '0000',
        company = null, latitude = null, longitude = null")
      Spree::TokenizedPermission.update_all("token = null")

      # Sanitize payments related entities
      Spree::PaymentMethod.update_all("name = concat('Dummy Payment Method', id),
                                       description = name")
      Spree::CreditCard.update_all("
        month = 12, year = 2020, start_month = 12, start_year = 2000,
        cc_type = 'VISA', first_name = 'Dummy', last_name = 'Dummy', last_digits = '2543'")
      Spree::Payment.update_all("response_code = null, avs_response = null,
                                 cvv_response_code = null, identifier = null,
                                 cvv_response_message = null")
      Spree::PaypalExpressCheckout.update_all("token = null")
      StripeAccount.delete_all
      ActiveRecord::Base.connection.execute("delete from spree_paypal_accounts")

      # Update environment in mail methods and payment methods
      ActiveRecord::Base.connection.execute("update spree_mail_methods set environment = '#{Rails.env}'")
      Spree::PaymentMethod.update_all("environment = '#{Rails.env}'")

      # Delete all preferences that may contain sensitive information
      Spree::Preference
        .where("key like '%gateway%' OR key like '%billing_integration%' OR key like '%s3%'")
        .delete_all
    end

    def guard_and_warn
      if Rails.env.production?
        Rails.logger.info("This task cannot be executed in production")
        exit
      end

      message = "\n <%= color('This will permanently change DB contents', :yellow) %>,
                are you sure you want to proceed? (y/N)"
      exit unless HighLine.new.agree(message) { |q| q.default = "n" }
    end
  end
end
