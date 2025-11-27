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

    const packages = window.prompt(this.createVoucherPromptValue, 1);
    if (packages === null) return;

    const numPackages = parseInt(packages, 10);
    if (isNaN(numPackages) || numPackages <= 0) {
      alert(this.createVoucherErrorValue);
      return;
    }

    await post(`${Spree.adminPath}/boxnow/${this.orderIdValue}/create`, {
      body: {
        num_packages: numPackages,
      },
    });

    Turbo.visit(window.location.href, { action: "replace" });
  }
}
