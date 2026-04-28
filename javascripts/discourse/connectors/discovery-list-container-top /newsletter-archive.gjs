// /connectors/discovery-list-container-top/newsletter-archive.gjs
import Component from "@glimmer/component";
import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";

class NewsletterCard extends Component {
  constructor(owner, args) {
    super(owner, args);
    this.args.onInsert(this.args.topic);
  }

  <template>
    <div class="newsletter-card-wrapper">
      {{#if @isLoading}}
        <div class="newsletter-card newsletter-card--loading">
          <div class="card-icon">⏳</div>
          <div class="card-info">
            <div class="card-title">{{@topic.fancy_title}}</div>
            <div class="card-date">Loading…</div>
          </div>
        </div>
      {{else if @pdfs.length}}
        {{#each @pdfs as |pdfUrl|}}
          <div class="newsletter-card">
            <div class="card-icon">📄</div>
            <div class="card-info">
              <div class="card-title">{{@topic.fancy_title}}</div>
              <div class="card-date">{{@formattedDate}}</div>
            </div>
            <a
              class="newsletter-download-btn"
              href={{pdfUrl}}
              target="_blank"
              rel="noopener noreferrer"
              download
            >
              ⬇ Download
            </a>
          </div>
        {{/each}}
      {{/if}}
    </div>
  </template>
}

export default class NewsletterArchive extends Component {
  @service router;

  @tracked pdfMap = {};
  @tracked loadingMap = {};

  get isNewsletterPage() {
    // Primary: check router URL — most reliable for this outlet
    const path = this.router.currentURL || "";
    const isRoute = path.includes("/c/newsletters") || path.includes("/c/newsletters/70");

    // Fallback: inspect every possible outletArgs shape
    const args = this.args.outletArgs;
    const slug =
      args?.category?.slug ||
      args?.parentCategory?.slug ||
      args?.model?.category?.slug ||
      args?.model?.list?.category?.slug ||
      args?.model?.list?.draft?.category_id;

    console.log("[newsletter] router path:", path);
    console.log("[newsletter] isRoute:", isRoute);
    console.log("[newsletter] outletArgs:", JSON.stringify(args, null, 2));

    return isRoute || slug === "newsletters";
  }

  get topics() {
    const args = this.args.outletArgs;
    return (
      args?.model?.list?.topics ||
      args?.model?.topics ||
      args?.topics ||
      []
    );
  }

  @action
  async loadUploads(topic) {
    const id = topic.id;
    if (this.pdfMap[id] !== undefined || this.loadingMap[id]) return;

    this.loadingMap = { ...this.loadingMap, [id]: true };

    try {
      const res = await ajax(`/t/${id}.json`);
      const uploads = res?.post_stream?.posts?.[0]?.uploads || [];
      this.pdfMap = {
        ...this.pdfMap,
        [id]: uploads
          .filter((u) => u.url?.toLowerCase().endsWith(".pdf"))
          .map((u) => u.url),
      };
    } catch (e) {
      console.error("[newsletter] PDF fetch failed for topic", id, e);
      this.pdfMap = { ...this.pdfMap, [id]: [] };
    } finally {
      this.loadingMap = { ...this.loadingMap, [id]: false };
    }
  }

  isLoading(topic) {
    return !!this.loadingMap[topic.id];
  }

  pdfsFor(topic) {
    return this.pdfMap[topic.id] || [];
  }

  formatDate(d) {
    if (!d) return "";
    const date = new Date(d);
    if (isNaN(date.getTime())) return "";
    return new Intl.DateTimeFormat("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    }).format(date);
  }

  <template>
    {{#if this.isNewsletterPage}}
      <div class="newsletter-archive">
        <h1 class="newsletter-title">📰 Newsletter Archive</h1>

        {{#if this.topics.length}}
          <div class="newsletter-grid">
            {{#each this.topics as |topic|}}
              <NewsletterCard
                @topic={{topic}}
                @onInsert={{this.loadUploads}}
                @isLoading={{this.isLoading topic}}
                @pdfs={{this.pdfsFor topic}}
                @formattedDate={{this.formatDate topic.created_at}}
              />
            {{/each}}
          </div>
        {{else}}
          <div class="newsletter-empty">
            No newsletters yet — check back soon.
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
