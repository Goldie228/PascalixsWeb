import "@hotwired/turbo-rails"
Turbo.session.drive = false;

import Rails from "@rails/ujs"
import consumer from "./channels/consumer"

window.App = { 
  cable: consumer,
  subscriptions: {}
}

import "./navbar"
import "./notifications"
import "./purchase_pass_modal"
import "./timezone"

Rails.start()

import "js-cookie";
import "controllers";
import "@hotwired/stimulus-loading";

import * as ClipboardModule from "clipboard";
window.ClipboardJS = ClipboardModule.default || ClipboardModule;

document.addEventListener('turbo:load', function() {
  if (window.ClipboardJS) {
    new ClipboardJS('[data-clipboard-text]');
  }
});

import "channels";
