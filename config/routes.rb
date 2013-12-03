Rails.application.routes.draw do

  match Easypay::Engine.config.easypay_notification_path => 'easypay/notifications#simple_notification', via: [:get, :post]
  match Easypay::Engine.config.easypay_forward_path => 'easypay/notifications#notification_to_forward', via: [:get, :post]
  match Easypay::Engine.config.easypay_payment_path => 'easypay/notifications#notification_from_payment', via: [:get, :post]
  match Easypay::Engine.config.redirect_after_payment_path => 'easypay/payments#complete', :as => :payment_redirect, via: [:get, :post]
  match Easypay::Engine.config.redirect_payment_notification_path => 'easypay/payments#notify', :as => :payment_notify, via: [:get, :post]
  
end
