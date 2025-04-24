import "@hotwired/turbo-rails";

import Rails from "@rails/ujs";
Rails.start();

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
