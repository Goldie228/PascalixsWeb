import "@hotwired/turbo-rails"
Turbo.session.drive = false;

import Rails from "@rails/ujs"
import consumer from "./channels/consumer"

window.App = { 
  cable: consumer,
  subscriptions: {}
}

Rails.start()

import "@hotwired/turbo-rails"

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

import "./timezone";
import "./account_drawer.js";
import "./purchase_pass_modal.js";
import "./navbar.js";
import "./notifications";
import "channels";
