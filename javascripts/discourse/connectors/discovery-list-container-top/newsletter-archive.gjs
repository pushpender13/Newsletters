// /connectors/discovery-list-container-top/newsletter-archive.gjs
import Component from "@glimmer/component";
import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";

// ─── Helpers ────────────────────────────────────────────────────────────────

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

// ─── Single row in the list ──────────────────────────────────────────────────

class NewsletterRow extends Component {
  constructor(owner, args) {
    super(owner, args);
    this.args.onInsert(this.args.topic);
  }

  <template>
    <div class="nla-row">
      <div class="nla-row__date">{{@formattedDate}}</div>
      <div class="nla-row__title">{{@topic.fancy_title}}</div>
      {{#if @isLoading}}
        <span class="nla-row__loading">Loading…</span>
      {{else if @pdfs.length}}
        {{#each @pdfs as |pdf|}}
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

// ─── Create Newsletter Modal (admin only) ────────────────────────────────────

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
      // 1. Upload the PDF
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

      // 2. Create the topic in category 70
      await ajax("/posts.json", {
        type: "POST",
        data: { title: this.title.trim(), raw: shortUrl, category: 70 },
      });

      this.args.onCreated();
    } catch (err) {
      console.error("[newsletter] create error", err);
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
            disabled={{if (not this.canSubmit) "disabled"}}
            {{on "click" this.submit}}
          >
            {{#if this.uploading}}
              <span class="nla-spin"></span>Uploading…
            {{else}}
              Publish
            {{/if}}
          </button>
        </div>

      </div>
    </div>
  </template>
}

// ─── Main connector ──────────────────────────────────────────────────────────

export default class NewsletterArchive extends Component {
  @service router;
  @service currentUser;

  @tracked pdfMap = {};
  @tracked loadingMap = {};
  @tracked showModal = false;

  get isNewsletterPage() {
    const path = this.router.currentURL || "";
    if (/\/c\/newsletters(\/|$)/.test(path)) return true;

    const args = this.args.outletArgs;
    const id =
      args?.category?.id ||
      args?.model?.category?.id ||
      args?.model?.list?.category?.id;
    const slug =
      args?.category?.slug ||
      args?.parentCategory?.slug ||
      args?.model?.category?.slug ||
      args?.model?.list?.category?.slug;

    return id === 70 || slug === "newsletters";
  }

  get isAdmin() {
    return this.currentUser?.admin === true;
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
          .filter(
            (u) =>
              u.url?.toLowerCase().endsWith(".pdf") ||
              u.original_filename?.toLowerCase().endsWith(".pdf")
          )
          .map((u) => u.url),
      };
    } catch (e) {
      console.error("[newsletter] fetch failed", id, e);
      this.pdfMap = { ...this.pdfMap, [id]: [] };
    } finally {
      this.loadingMap = { ...this.loadingMap, [id]: false };
    }
  }

  isLoading(topic) { return !!this.loadingMap[topic.id]; }
  pdfsFor(topic)   { return this.pdfMap[topic.id] || []; }

  @action openModal()  { this.showModal = true; }
  @action closeModal() { this.showModal = false; }
  @action onCreated()  { this.showModal = false; window.location.reload(); }

  <template>
    {{#if this.isNewsletterPage}}
      <div class="nla-wrap">

        {{! ── Page header ── }}
        <div class="nla-header">
          <div class="nla-header__text">
            <h1 class="nla-header__title">Past Editions</h1>
            <p class="nla-header__sub">Browse and download past issues of the Newsletter.</p>
          </div>
          {{#if this.isAdmin}}
            <button class="nla-btn nla-btn--primary" type="button" {{on "click" this.openModal}}>
              <svg viewBox="0 0 16 16" fill="none"><path d="M8 2v12M2 8h12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
              New Newsletter
            </button>
          {{/if}}
        </div>

        {{! ── List ── }}
        {{#if this.topics.length}}
          <div class="nla-list">
            {{#each this.topics as |topic|}}
              <NewsletterRow
                @topic={{topic}}
                @onInsert={{this.loadUploads}}
                @isLoading={{this.isLoading topic}}
                @pdfs={{this.pdfsFor topic}}
                @formattedDate={{fmtDate topic.created_at}}
              />
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

        {{! ── Modal ── }}
        {{#if this.showModal}}
          <CreateNewsletterModal @onClose={{this.closeModal}} @onCreated={{this.onCreated}} />
        {{/if}}

      </div>

      {{! ── Scoped styles ── }}
      <style>
        /* Base */
        .nla-wrap {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          color: #1a2e3b;
          max-width: 860px;
          margin: 0 auto 2.5rem;
          padding: 0 4px;
        }

        /* Header */
        .nla-header {
          display: flex;
          align-items: flex-start;
          justify-content: space-between;
          gap: 1rem;
          padding-bottom: 1.25rem;
          margin-bottom: 0;
          flex-wrap: wrap;
        }
        .nla-header__title {
          margin: 0 0 4px;
          font-size: 1.75rem;
          font-weight: 800;
          color: #0f2030;
          line-height: 1.15;
        }
        .nla-header__sub {
          margin: 0;
          font-size: 0.9375rem;
          color: #5a7282;
        }

        /* Buttons */
        .nla-btn {
          display: inline-flex;
          align-items: center;
          gap: 6px;
          padding: 0.5rem 1.1rem;
          border-radius: 7px;
          font-size: 0.875rem;
          font-weight: 600;
          cursor: pointer;
          border: none;
          transition: background 0.14s, opacity 0.14s;
          text-decoration: none;
          white-space: nowrap;
          line-height: 1;
        }
        .nla-btn svg { width: 14px; height: 14px; flex-shrink: 0; }
        .nla-btn--primary   { background: #1a6e5c; color: #fff; }
        .nla-btn--primary:hover { background: #155a4a; }
        .nla-btn--primary:disabled { opacity: 0.5; cursor: not-allowed; }
        .nla-btn--busy      { opacity: 0.7; cursor: wait; }
        .nla-btn--ghost     { background: #f0f4f6; color: #374151; border: 1px solid #d1d9df; }
        .nla-btn--ghost:hover { background: #e4eaed; }
        .nla-btn--outline   { background: transparent; color: #1a6e5c; border: 1.5px solid #1a6e5c; }
        .nla-btn--outline:hover { background: #f0faf7; }

        /* List */
        .nla-list {
          display: flex;
          flex-direction: column;
        }

        /* Row */
        .nla-row {
          padding: 1.1rem 0;
          border-top: 1px solid #d8e2e6;
          display: flex;
          flex-direction: column;
          gap: 3px;
        }
        .nla-row:last-child { border-bottom: 1px solid #d8e2e6; }
        .nla-row__date {
          font-size: 0.8125rem;
          font-weight: 700;
          color: #4a6070;
          letter-spacing: 0.01em;
        }
        .nla-row__title {
          font-size: 1.0625rem;
          font-weight: 700;
          color: #0f2030;
          line-height: 1.35;
          margin-bottom: 2px;
        }
        .nla-row__loading {
          font-size: 0.8125rem;
          color: #8fa5b0;
        }
        .nla-row__download {
          display: inline-flex;
          align-items: center;
          gap: 5px;
          color: #1a6e5c;
          font-size: 0.875rem;
          font-weight: 600;
          text-decoration: none;
          width: fit-content;
        }
        .nla-row__download:hover { text-decoration: underline; }
        .nla-row__dl-icon { width: 16px; height: 16px; flex-shrink: 0; }

        /* Empty */
        .nla-empty {
          padding: 3rem 0;
          display: flex;
          flex-direction: column;
          align-items: flex-start;
          gap: 1rem;
          color: #5a7282;
          font-size: 0.9375rem;
          border-top: 1px solid #d8e2e6;
        }
        .nla-empty p { margin: 0; }

        /* Modal backdrop */
        .nla-backdrop {
          position: fixed;
          inset: 0;
          background: rgba(10, 20, 30, 0.48);
          display: flex;
          align-items: center;
          justify-content: center;
          z-index: 10000;
          padding: 1rem;
          backdrop-filter: blur(3px);
        }

        /* Modal */
        .nla-modal {
          background: #fff;
          border-radius: 14px;
          width: 100%;
          max-width: 460px;
          box-shadow: 0 24px 64px rgba(0,0,0,0.2);
          display: flex;
          flex-direction: column;
          overflow: hidden;
          animation: nla-in 0.18s ease;
        }
        @keyframes nla-in {
          from { opacity: 0; transform: translateY(10px) scale(0.98); }
          to   { opacity: 1; transform: none; }
        }
        .nla-modal__head {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 1.125rem 1.375rem 0.875rem;
          border-bottom: 1px solid #edf0f2;
        }
        .nla-modal__title {
          margin: 0;
          font-size: 1rem;
          font-weight: 700;
          color: #0f2030;
        }
        .nla-modal__x {
          display: flex;
          align-items: center;
          justify-content: center;
          width: 30px; height: 30px;
          border: none;
          background: transparent;
          cursor: pointer;
          color: #8fa5b0;
          border-radius: 6px;
          transition: background 0.13s, color 0.13s;
        }
        .nla-modal__x svg { width: 16px; height: 16px; }
        .nla-modal__x:hover { background: #f0f4f6; color: #374151; }
        .nla-modal__body {
          padding: 1.25rem 1.375rem;
          display: flex;
          flex-direction: column;
          gap: 1rem;
        }
        .nla-modal__foot {
          display: flex;
          justify-content: flex-end;
          gap: 0.625rem;
          padding: 0.875rem 1.375rem 1.125rem;
          border-top: 1px solid #edf0f2;
        }

        /* Form fields */
        .nla-field { display: flex; flex-direction: column; gap: 5px; }
        .nla-field__lbl { font-size: 0.8125rem; font-weight: 600; color: #2e4452; }
        .nla-field__inp {
          width: 100%;
          padding: 0.5rem 0.75rem;
          border: 1.5px solid #c8d5db;
          border-radius: 7px;
          font-size: 0.9375rem;
          color: #1a2e3b;
          background: #fff;
          outline: none;
          box-sizing: border-box;
          transition: border-color 0.13s, box-shadow 0.13s;
        }
        .nla-field__inp::placeholder { color: #8fa5b0; }
        .nla-field__inp:focus { border-color: #1a6e5c; box-shadow: 0 0 0 3px rgba(26,110,92,0.13); }

        /* Drop zone */
        .nla-drop {
          position: relative;
          border: 2px dashed #c8d5db;
          border-radius: 9px;
          padding: 1.375rem 1rem;
          display: flex;
          flex-direction: column;
          align-items: center;
          gap: 0.4rem;
          cursor: pointer;
          background: #f8fafb;
          text-align: center;
          transition: border-color 0.13s, background 0.13s;
        }
        .nla-drop:hover, .nla-drop--over { border-color: #1a6e5c; background: #f0faf7; }
        .nla-drop__inp {
          position: absolute;
          inset: 0;
          opacity: 0;
          cursor: pointer;
          width: 100%;
          height: 100%;
        }
        .nla-drop__ico { width: 20px; height: 20px; color: #1a6e5c; }
        .nla-drop__ico--lg { width: 36px; height: 36px; color: #8fa5b0; margin-bottom: 2px; }
        .nla-drop__name { font-size: 0.875rem; font-weight: 600; color: #0f2030; }
        .nla-drop__change { font-size: 0.75rem; color: #1a6e5c; text-decoration: underline; cursor: pointer; }
        .nla-drop__txt { margin: 0; font-size: 0.875rem; color: #5a7282; }
        .nla-drop__browse { color: #1a6e5c; font-weight: 600; }

        /* Error */
        .nla-err {
          background: #fff5f5;
          border: 1px solid #fcc;
          color: #c0392b;
          border-radius: 7px;
          padding: 0.5rem 0.75rem;
          font-size: 0.8125rem;
          line-height: 1.5;
        }

        /* Spinner */
        .nla-spin {
          display: inline-block;
          width: 13px; height: 13px;
          border: 2px solid rgba(255,255,255,0.35);
          border-top-color: #fff;
          border-radius: 50%;
          animation: nla-spin 0.65s linear infinite;
          flex-shrink: 0;
        }
        @keyframes nla-spin { to { transform: rotate(360deg); } }

        /* Responsive */
        @media (max-width: 560px) {
          .nla-header { flex-direction: column; }
          .nla-header__title { font-size: 1.375rem; }
        }
      </style>
    {{/if}}
  </template>
}
