# frozen_string_literal: true

require 'cgi'

module Audio
  class SegmentFixReport
    CATEGORY_LABELS = {
      'missing_segments'   => 'Missing segments',
      'ayah_timing'        => 'Ayah timing',
      'ayah_overlap'       => 'Ayah overlap',
      'ayah_gap'           => 'Ayah gap',
      'missing_words'      => 'Missing words',
      'word_timing'        => 'Word timing',
      'word_overlap'       => 'Words overlap',
      'word_past_duration' => 'Past audio duration',
      'trailing_gap'       => 'Trailing gap',
      'repeated_words'     => 'Repeated words'
    }.freeze

    SEVERITY = {
      'missing_segments'   => 'critical',
      'ayah_timing'        => 'critical',
      'ayah_overlap'       => 'critical',
      'trailing_gap'       => 'critical',
      'ayah_gap'           => 'warning',
      'missing_words'      => 'warning',
      'word_timing'        => 'warning',
      'word_overlap'       => 'warning',
      'word_past_duration' => 'warning',
      'repeated_words'     => 'info'
    }.freeze

    CATEGORY_ORDER = %w[
      missing_segments ayah_timing ayah_overlap ayah_gap trailing_gap
      missing_words word_timing word_overlap word_past_duration repeated_words
    ].freeze

    def initialize(recitation, result, applied:, generated_at:, base_url: 'http://localhost:3000')
      @recitation = recitation
      @result = result
      @applied = applied
      @generated_at = generated_at
      @base_url = base_url.to_s.sub(%r{/\z}, '')
    end

    def to_html
      <<~HTML
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Segment fix report — recitation #{@recitation.id}</title>
        </head>
        <body>
        #{inner_html}
        </body>
        </html>
      HTML
    end

    def inner_html
      [styles, header, stat_cards, summary_table, filter_bar, fixed_section, pending_section, script].join("\n")
    end

    private

    def total_before
      @result.before.values.sum
    end

    def total_fixed
      @result.fixed.values.sum
    end

    def total_skipped
      @result.skipped.values.sum
    end

    def total_after
      @result.after.values.sum
    end

    def header
      mode = @applied ? 'Applied' : 'Dry-run'
      mode_class = @applied ? 'badge badge--applied' : 'badge badge--dry'

      <<~HTML
        <header class="masthead">
          <div class="masthead__eyebrow">Audio segment QA</div>
          <h1 class="masthead__title">Auto-fix report</h1>
          <div class="masthead__meta">
            <span><span class="k">Recitation</span> ##{@recitation.id} · #{h(@recitation.name)}</span>
            <span><span class="k">Generated</span> #{h(@generated_at)}</span>
            <span class="#{mode_class}">#{mode}</span>
          </div>
        </header>
      HTML
    end

    def stat_cards
      <<~HTML
        <section class="stats">
          #{stat_card('Issues found', total_before, 'neutral')}
          #{stat_card('Auto-fixed', total_fixed, 'positive')}
          #{stat_card('Skipped (unsafe)', total_skipped, 'warning')}
          #{stat_card('Still pending', total_after, 'critical')}
        </section>
      HTML
    end

    def stat_card(label, value, tone)
      <<~HTML
        <div class="stat stat--#{tone}">
          <div class="stat__value">#{value}</div>
          <div class="stat__label">#{label}</div>
        </div>
      HTML
    end

    def summary_table
      categories = (CATEGORY_ORDER & (@result.before.keys | @result.after.keys | @result.fixed.keys)) +
                   ((@result.before.keys | @result.after.keys | @result.fixed.keys) - CATEGORY_ORDER)

      rows = categories.map do |category|
        <<~ROW
          <tr>
            <td>#{severity_dot(category)} #{h(label_for(category))}</td>
            <td class="num">#{@result.before[category].to_i}</td>
            <td class="num num--pos">#{@result.fixed[category].to_i}</td>
            <td class="num num--warn">#{@result.skipped[category].to_i}</td>
            <td class="num num--crit">#{@result.after[category].to_i}</td>
          </tr>
        ROW
      end.join

      <<~HTML
        <section class="panel">
          <h2 class="panel__title">By category</h2>
          <div class="table-wrap">
            <table class="grid">
              <thead>
                <tr><th>Category</th><th class="num">Found</th><th class="num">Fixed</th><th class="num">Skipped</th><th class="num">Pending</th></tr>
              </thead>
              <tbody>
                #{rows}
              </tbody>
              <tfoot>
                <tr>
                  <td>Total</td>
                  <td class="num">#{total_before}</td>
                  <td class="num num--pos">#{total_fixed}</td>
                  <td class="num num--warn">#{total_skipped}</td>
                  <td class="num num--crit">#{total_after}</td>
                </tr>
              </tfoot>
            </table>
          </div>
        </section>
      HTML
    end

    def filter_bar
      <<~HTML
        <div class="filter">
          <input type="search" id="filter-input" placeholder="Filter by ayah (e.g. 32:1) or text…" aria-label="Filter rows">
          <span class="filter__hint">Type to filter both tables below.</span>
        </div>
      HTML
    end

    def fixed_section
      rows = @result.changes.map do |change|
        <<~ROW
          <tr data-search="#{h(change[:verse_key])} #{h(label_for(change[:category]))} #{h(change[:target])}">
            <td>#{ayah_link(change[:chapter_id], change[:verse_number], change[:verse_key])}</td>
            <td><span class="pill pill--#{severity_for(change[:category])}">#{h(label_for(change[:category]))}</span></td>
            <td>#{h(change[:target])}</td>
            <td class="num num--old">#{change[:old_value]}</td>
            <td class="num num--new">#{change[:new_value]}</td>
          </tr>
        ROW
      end.join

      empty = @result.changes.empty? ? '<p class="empty">Nothing was auto-fixed.</p>' : ''

      <<~HTML
        <section class="panel" id="fixed">
          <h2 class="panel__title">Auto-fixed <span class="count">#{@result.changes.size}</span></h2>
          #{empty}
          <div class="table-wrap">
            <table class="grid grid--data">
              <thead>
                <tr><th>Ayah</th><th>Category</th><th>Field</th><th class="num">Old (ms)</th><th class="num">New (ms)</th></tr>
              </thead>
              <tbody>
                #{rows}
              </tbody>
            </table>
          </div>
        </section>
      HTML
    end

    def pending_section
      rows = @result.pending.map do |issue|
        chapter_id, verse_number = parse_key(issue[:key])
        link = chapter_id ? ayah_link(chapter_id, verse_number, issue[:key]) : '—'

        <<~ROW
          <tr data-search="#{h(issue[:key])} #{h(label_for(issue[:category]))} #{h(issue[:text])}">
            <td>#{link}</td>
            <td><span class="pill pill--#{severity_for(issue[:category])}">#{h(label_for(issue[:category]))}</span></td>
            <td>#{h(issue[:text])}</td>
          </tr>
        ROW
      end.join

      empty = @result.pending.empty? ? '<p class="empty">No issues remain. 🎉</p>' : ''

      <<~HTML
        <section class="panel" id="pending">
          <h2 class="panel__title">Still needs review <span class="count">#{@result.pending.size}</span></h2>
          <p class="panel__note">These could not be fixed mechanically (real gaps, repetition, or fixes that would invert timestamps). Open each in the segments tool.</p>
          #{empty}
          <div class="table-wrap">
            <table class="grid grid--data">
              <thead>
                <tr><th>Ayah</th><th>Category</th><th>Issue</th></tr>
              </thead>
              <tbody>
                #{rows}
              </tbody>
            </table>
          </div>
        </section>
      HTML
    end

    def script
      <<~HTML
        <script>
          (function () {
            var input = document.getElementById('filter-input');
            if (!input) return;
            var rows = Array.prototype.slice.call(document.querySelectorAll('tr[data-search]'));
            input.addEventListener('input', function () {
              var q = input.value.trim().toLowerCase();
              rows.forEach(function (row) {
                var hay = row.getAttribute('data-search').toLowerCase();
                row.style.display = (!q || hay.indexOf(q) !== -1) ? '' : 'none';
              });
            });
          })();
        </script>
      HTML
    end

    def ayah_link(chapter_id, verse_number, label)
      %(<a class="ayah" href="#{segment_url(chapter_id, verse_number)}" target="_blank" rel="noopener">#{h(label)}<span class="ayah__go">↗</span></a>)
    end

    def segment_url(chapter_id, verse_number)
      "#{@base_url}/surah_audio_files/#{@recitation.id}/segment_builder?chapter_id=#{chapter_id}&verse=#{verse_number}"
    end

    def parse_key(key)
      return [nil, nil] if key.nil?

      chapter_id, verse_number = key.to_s.split(':')
      [chapter_id, verse_number]
    end

    def label_for(category)
      CATEGORY_LABELS[category] || category.to_s.tr('_', ' ')
    end

    def severity_for(category)
      SEVERITY[category] || 'info'
    end

    def severity_dot(category)
      %(<span class="dot dot--#{severity_for(category)}"></span>)
    end

    def h(text)
      CGI.escapeHTML(text.to_s)
    end

    def styles
      <<~CSS
        <style>
          :root {
            --ink: #14181f;
            --ink-soft: #47505c;
            --ink-faint: #7b8593;
            --ground: #f7f8fa;
            --surface: #ffffff;
            --line: #e3e7ec;
            --line-soft: #eef1f4;
            --accent: #12634a;
            --critical: #c0384b;
            --warning: #b7791f;
            --positive: #12806a;
            --info: #6b7280;
            --mono: ui-monospace, "SF Mono", "SFMono-Regular", Menlo, Consolas, monospace;
            --sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          }
          * { box-sizing: border-box; }
          body {
            margin: 0;
            background: var(--ground);
            color: var(--ink);
            font-family: var(--sans);
            font-size: 14px;
            line-height: 1.5;
            -webkit-font-smoothing: antialiased;
          }
          .masthead, .stats, .panel, .filter { max-width: 1080px; margin-left: auto; margin-right: auto; }
          .masthead {
            padding: 40px 24px 24px;
          }
          .masthead__eyebrow {
            font-size: 11px; letter-spacing: .14em; text-transform: uppercase;
            color: var(--accent); font-weight: 700;
          }
          .masthead__title {
            font-size: 30px; font-weight: 700; letter-spacing: -.02em; margin: 4px 0 14px;
            text-wrap: balance;
          }
          .masthead__meta {
            display: flex; flex-wrap: wrap; gap: 8px 20px; align-items: center;
            color: var(--ink-soft); font-size: 13px;
          }
          .masthead__meta .k { color: var(--ink-faint); margin-right: 4px; }
          .badge {
            font-size: 11px; font-weight: 700; letter-spacing: .06em; text-transform: uppercase;
            padding: 3px 9px; border-radius: 999px;
          }
          .badge--dry { background: #fdf3e0; color: var(--warning); }
          .badge--applied { background: #e2f4ee; color: var(--positive); }
          .stats {
            display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px;
            padding: 0 24px 8px;
          }
          .stat {
            background: var(--surface); border: 1px solid var(--line); border-radius: 10px;
            padding: 16px 18px; border-left-width: 3px;
          }
          .stat__value { font-family: var(--mono); font-size: 26px; font-weight: 600; font-variant-numeric: tabular-nums; }
          .stat__label { font-size: 12px; color: var(--ink-soft); margin-top: 2px; }
          .stat--neutral { border-left-color: var(--ink-faint); }
          .stat--positive { border-left-color: var(--positive); }
          .stat--positive .stat__value { color: var(--positive); }
          .stat--warning { border-left-color: var(--warning); }
          .stat--warning .stat__value { color: var(--warning); }
          .stat--critical { border-left-color: var(--critical); }
          .stat--critical .stat__value { color: var(--critical); }
          .panel { padding: 20px 24px; }
          .panel__title {
            font-size: 15px; font-weight: 700; letter-spacing: -.01em; margin: 0 0 12px;
            display: flex; align-items: center; gap: 10px;
          }
          .panel__note { color: var(--ink-soft); font-size: 13px; margin: -6px 0 14px; max-width: 68ch; }
          .count {
            font-family: var(--mono); font-size: 12px; font-weight: 600;
            background: var(--line-soft); color: var(--ink-soft); padding: 2px 8px; border-radius: 999px;
          }
          .filter {
            padding: 4px 24px 0; display: flex; align-items: center; gap: 12px; flex-wrap: wrap;
          }
          .filter input {
            flex: 1 1 320px; min-width: 220px;
            padding: 9px 12px; border: 1px solid var(--line); border-radius: 8px;
            font-family: var(--sans); font-size: 13px; background: var(--surface); color: var(--ink);
          }
          .filter input:focus-visible { outline: 2px solid var(--accent); outline-offset: 1px; }
          .filter__hint { color: var(--ink-faint); font-size: 12px; }
          .table-wrap {
            overflow-x: auto; background: var(--surface);
            border: 1px solid var(--line); border-radius: 10px;
          }
          table.grid { width: 100%; border-collapse: collapse; font-size: 13px; }
          table.grid th {
            text-align: left; font-size: 11px; letter-spacing: .06em; text-transform: uppercase;
            color: var(--ink-faint); font-weight: 700;
            padding: 10px 14px; border-bottom: 1px solid var(--line); background: var(--ground);
            position: sticky; top: 0;
          }
          table.grid td { padding: 9px 14px; border-bottom: 1px solid var(--line-soft); vertical-align: top; }
          table.grid tbody tr:last-child td { border-bottom: none; }
          table.grid tbody tr:hover { background: #fbfcfd; }
          table.grid tfoot td {
            padding: 10px 14px; border-top: 1px solid var(--line); font-weight: 700;
            background: var(--ground);
          }
          .num { font-family: var(--mono); font-variant-numeric: tabular-nums; text-align: right; white-space: nowrap; }
          .num--pos { color: var(--positive); }
          .num--warn { color: var(--warning); }
          .num--crit { color: var(--critical); }
          .num--old { color: var(--ink-faint); text-decoration: line-through; }
          .num--new { color: var(--positive); font-weight: 600; }
          .ayah {
            font-family: var(--mono); font-size: 12.5px; color: var(--accent); font-weight: 600;
            text-decoration: none; white-space: nowrap; display: inline-flex; align-items: center; gap: 4px;
          }
          .ayah:hover { text-decoration: underline; }
          .ayah__go { color: var(--ink-faint); font-size: 11px; }
          .pill {
            display: inline-block; font-size: 11px; font-weight: 600; padding: 2px 9px; border-radius: 999px;
            white-space: nowrap;
          }
          .pill--critical { background: #fbe6e9; color: var(--critical); }
          .pill--warning { background: #fbf0dc; color: var(--warning); }
          .pill--info { background: #eef1f4; color: var(--info); }
          .dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; vertical-align: middle; margin-right: 4px; }
          .dot--critical { background: var(--critical); }
          .dot--warning { background: var(--warning); }
          .dot--info { background: var(--info); }
          .empty { color: var(--ink-soft); font-size: 13px; padding: 8px 0 14px; }
          @media (max-width: 640px) {
            .stats { grid-template-columns: repeat(2, 1fr); }
            .masthead { padding-top: 28px; }
          }
        </style>
      CSS
    end
  end
end
