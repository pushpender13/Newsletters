import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { ajax } from "discourse/lib/ajax";

const CATEGORY_SLUG = "newsletters";
const CATEGORY_ID = 70;

function fmtDate(d) {
  if (!d) return "";
  const date = new Date(d);
  if (isNaN(date.getTime())) return "";
  return new Intl.DateTimeFormat("en-US", {
    month: "long",
    day: "numeric",
    year: "numeric",
  }).format(date);
}

class NewsletterRow extends Component {
  @tracked pdfs = null;
  @tracked loading = true;

  constructor(owner, args) {
    super(owner, args);
    this.fetchPdfs();
  }

  async fetchPdfs() {
    try {
      const res = await ajax(`/t/${this.args.topic.id}.json`);
      const firstPost = res?.post_stream?.posts?.[0];
      const uploads = firstPost?.uploads || [];
      const cooked = firstPost?.cooked || "";

      const pdfUrls = uploads
        .filter(
          (u) =>
            u.url?.toLowerCase().endsWith(".pdf") ||
            u.original_filename?.toLowerCase().endsWith(".pdf")
        )
        .map((u) => u.url);

      if (pdfUrls.length === 0) {
        const hrefMatch = cooked.match(/href="([^"]*\.pdf[^"]*)"/i);
        if (hrefMatch) pdfUrls.push(hrefMatch[1]);
      }

      this.pdfs = pdfUrls;
    } catch (e) {
      this.pdfs = [];
    } finally {
      this.loading = false;
    }
  }

  <template>
    <div class="nla-row">
      <div class="nla-row__date">{{fmtDate @topic.created_at}}</div>
      <div class="nla-row__title">{{@topic.fancy_title}}</div>
      {{#if this.loading}}
        <span class="nla-row__loading">Loading...</span>
      {{else if this.pdfs.length}}
        {{#each this.pdfs as |pdf|}}
          <a
            class="nla-row__download"
            href={{pdf}}
            target="_blank"
            rel="noopener noreferrer"
            download
          >
            <svg class="nla-row__dl-icon" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">
              <rect x="1" y="1" width="16" height="16" rx="3" stroke="currentColor" stroke-width="1.4" fill="none"/>
              <path d="M5 7h3V4h2v3h3l-4 4-4-4z" fill="currentColor"/>
              <path d="M5 13h8" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/>
            </svg>
            Download PDF
          </a>
        {{/each}}
      {{/if}}
    </div>
  </template>
}

class CreateNewsletterModal extends Component {
  @tracked title = "";
  @tracked pdfFile = null;
  @tracked pdfName = "";
  @tracked uploading = false;
  @tracked error = "";
  @tracked dragOver = false;

  get canSubmit() {
    return this.title.trim().length > 0 && this.pdfFile !== null && !this.uploading;
  }

  @action updateTitle(e) { this.title = e.target.value; }

  @action
  pickFile(e) {
    const f = e.target.files?.[0];
    if (f) { this.pdfFile = f; this.pdfName = f.name; this.error = ""; }
  }

  @action dragover(e) { e.preventDefault(); this.dragOver = true; }
  @action dragleave() { this.dragOver = false; }

  @action
  drop(e) {
    e.preventDefault();
    this.dragOver = false;
    const f = e.dataTransfer.files?.[0];
    if (f && (f.type === "application/pdf" || f.name.toLowerCase().endsWith(".pdf"))) {
      this.pdfFile = f; this.pdfName = f.name; this.error = "";
    } else {
      this.error = "Please drop a PDF file.";
    }
  }

  @action
  backdropClick(e) {
    if (e.target === e.currentTarget) this.args.onClose();
  }

  @action
  async submit() {
    if (!this.canSubmit) return;
    this.uploading = true;
    this.error = "";
    try {
      const fd = new FormData();
      fd.append("files[]", this.pdfFile, this.pdfName);
      fd.append("type", "composer");
      const up = await ajax("/uploads.json", {
        type: "POST",
        data: fd,
        processData: false,
        contentType: false,
      });
      const shortUrl = up?.short_url;
      if (!shortUrl) throw new Error("Upload failed — no short_url returned.");

      await ajax("/posts.json", {
        type: "POST",
        data: { title: this.title.trim(), raw: shortUrl, category: CATEGORY_ID },
      });

      this.args.onCreated();
    } catch (err) {
      this.error =
        err?.jqXHR?.responseJSON?.errors?.[0] ||
        err?.message ||
        "Something went wrong. Please try again.";
    } finally {
      this.uploading = false;
    }
  }

  <template>
    <div class="nla-backdrop" {{on "click" this.backdropClick}}>
      <div class="nla-modal" role="dialog" aria-modal="true" aria-labelledby="nla-modal-title">

        <div class="nla-modal__head">
          <h2 class="nla-modal__title" id="nla-modal-title">New Newsletter</h2>
          <button class="nla-modal__x" type="button" {{on "click" @onClose}} aria-label="Close">
            <svg viewBox="0 0 16 16" fill="none"><path d="M3 3l10 10M13 3L3 13" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
          </button>
        </div>

        <div class="nla-modal__body">
          <label class="nla-field">
            <span class="nla-field__lbl">Title</span>
            <input
              class="nla-field__inp"
              type="text"
              placeholder="e.g. April 28, 2026 — Community Update"
              value={{this.title}}
              {{on "input" this.updateTitle}}
            />
          </label>

          <div class="nla-field">
            <span class="nla-field__lbl">PDF File</span>
            <div
              class="nla-drop {{if this.dragOver 'nla-drop--over'}}"
              {{on "dragover" this.dragover}}
              {{on "dragleave" this.dragleave}}
              {{on "drop" this.drop}}
            >
              <input class="nla-drop__inp" type="file" accept=".pdf,application/pdf" {{on "change" this.pickFile}} />
              {{#if this.pdfName}}
                <svg class="nla-drop__ico" viewBox="0 0 24 24" fill="none"><path d="M5 4a2 2 0 0 1 2-2h7l5 5v13a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V4z" stroke="currentColor" stroke-width="1.5" fill="none"/><path d="M14 2v5h5" stroke="currentColor" stroke-width="1.5" fill="none"/></svg>
                <span class="nla-drop__name">{{this.pdfName}}</span>
                <span class="nla-drop__change">Change file</span>
              {{else}}
                <svg class="nla-drop__ico nla-drop__ico--lg" viewBox="0 0 40 40" fill="none"><path d="M20 26V14M20 14l-5 5M20 14l5 5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/><path d="M10 28a6 6 0 0 1 0-12 8 8 0 0 1 16 0 6 6 0 0 1 0 12" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" fill="none"/></svg>
                <p class="nla-drop__txt">Drag &amp; drop PDF here, or <span class="nla-drop__browse">browse</span></p>
              {{/if}}
            </div>
          </div>

          {{#if this.error}}
            <div class="nla-err">{{this.error}}</div>
          {{/if}}
        </div>

        <div class="nla-modal__foot">
          <button class="nla-btn nla-btn--ghost" type="button" {{on "click" @onClose}}>Cancel</button>
          <button
            class="nla-btn nla-btn--primary {{if this.uploading 'nla-btn--busy'}}"
            type="button"
            disabled={{if this.canSubmit false true}}
            {{on "click" this.submit}}
          >
            {{#if this.uploading}}
              <span class="nla-spin"></span>Uploading...
            {{else}}
              Publish
            {{/if}}
          </button>
        </div>

      </div>
    </div>
  </template>
}

export default class NewsletterArchive extends Component {
  @service router;
  @service currentUser;
  @service store;

  @tracked topics = [];
  @tracked loading = true;
  @tracked showModal = false;

  get isNewsletterPage() {
    const outletArgs = this.args.outletArgs || {};
    const id = outletArgs.category?.id;
    const slug = outletArgs.category?.slug;
    if (id === CATEGORY_ID || slug === CATEGORY_SLUG) return true;

    const path = this.router.currentURL || "";
    return /\/c\/newsletters(\/|$)/.test(path);
  }

  get isAdmin() {
    return this.currentUser?.admin === true;
  }

  constructor(owner, args) {
    super(owner, args);
    if (this.isNewsletterPage) {
      this.fetchTopics();
    } else {
      this.loading = false;
    }
  }

  async fetchTopics() {
    this.loading = true;
    try {
      const allTopics = [];
      let page = 0;
      let keepGoing = true;

      while (keepGoing) {
        const url = `/c/${CATEGORY_SLUG}/${CATEGORY_ID}/l/latest.json?page=${page}`;
        const res = await ajax(url);
        const batch = res?.topic_list?.topics || [];

        if (batch.length === 0) {
          keepGoing = false;
        } else {
          allTopics.push(...batch);
          keepGoing = !!res?.topic_list?.more_topics_url;
          page++;
        }

        if (page > 20) keepGoing = false;
      }

      this.topics = allTopics.filter(
        (t) => !t.title?.toLowerCase().startsWith("about the ")
      );
    } catch (e) {
      this.topics = [];
    } finally {
      this.loading = false;
    }
  }

  @action openModal()  { this.showModal = true; }
  @action closeModal() { this.showModal = false; }

  @action
  onCreated() {
    this.showModal = false;
    window.location.reload();
  }

  <template>
    {{#if this.isNewsletterPage}}
      <div class="nla-wrap">

        <div class="nla-header">
          <div class="nla-header__text">
            <h1 class="nla-header__title">Past Editions</h1>
            <p class="nla-header__sub">Browse and download past issues of the MASH Newsletter.</p>
          </div>
          {{#if this.isAdmin}}
            <button class="nla-btn nla-btn--primary" type="button" {{on "click" this.openModal}}>
              <svg viewBox="0 0 16 16" fill="none"><path d="M8 2v12M2 8h12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
              New Newsletter
            </button>
          {{/if}}
        </div>

        {{#if this.loading}}
          <div class="nla-loading-state">
            <span class="nla-spin nla-spin--lg"></span>
          </div>
        {{else if this.topics.length}}
          <div class="nla-list">
            {{#each this.topics as |topic|}}
              <NewsletterRow @topic={{topic}} />
            {{/each}}
          </div>
        {{else}}
          <div class="nla-empty">
            <p>No newsletters yet — check back soon.</p>
            {{#if this.isAdmin}}
              <button class="nla-btn nla-btn--outline" type="button" {{on "click" this.openModal}}>
                Publish the first edition
              </button>
            {{/if}}
          </div>
        {{/if}}

        {{#if this.showModal}}
          <CreateNewsletterModal @onClose={{this.closeModal}} @onCreated={{this.onCreated}} />
        {{/if}}

      </div>
    {{/if}}
  </template>
}
