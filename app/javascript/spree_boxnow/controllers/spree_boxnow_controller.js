import { Controller } from "@hotwired/stimulus";
import { post } from "@rails/request.js";

export default class extends Controller {
  static values = {
    orderId: Number,
    createVoucherPrompt: String,
    createVoucherError: String,
  };

  async createVoucher(event) {
    event.preventDefault();

    const value = window.confirm(this.createVoucherPromptValue);
    if (!value) return;

    await post(`${Spree.adminPath}/boxnow/${this.orderIdValue}/create`);

    Turbo.visit(window.location.href, { action: "replace" });
  }
}
