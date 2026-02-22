# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Streaming::Core::Observability::Metrics do
  describe 'when enabled: true (default)' do
    subject(:metrics) { described_class.new(enabled: true) }

    it 'accumulates track_* and returns real data in to_h and event_stats' do
      metrics.track_event_emitted(:candle)
      metrics.track_event_processed(:candle, 1.5)
      metrics.track_callback_success(:candle)
      metrics.track_callback_latency(:candle, 2.0)

      expect(metrics.event_stats(:candle)).to include(
        emitted: 1,
        processed: 1,
        success: 1,
        avg_latency_ms: be > 0
      )
      h = metrics.to_h
      expect(h[:events_emitted]).to eq(candle: 1)
      expect(h[:error_count]).to eq(0)
    end
  end

  describe 'when enabled: false' do
    subject(:metrics) { described_class.new(enabled: false) }

    describe '#to_h' do
      it 'returns zero-shape with optional queue depths' do
        payload = metrics.to_h(queue_depth: 2, worker_queue_depth: 3)

        expect(payload).to eq(
          uptime_seconds: 0.0,
          events_emitted: {},
          events_processed: {},
          callbacks_success: {},
          callbacks_error: {},
          latency_stats: {},
          error_count: 0,
          queue_depth: 2,
          worker_queue_depth: 3
        )
      end
    end

    describe '#event_stats' do
      it 'returns zero-shape for any event type' do
        expect(metrics.event_stats(:candle)).to eq(
          emitted: 0,
          processed: 0,
          success: 0,
          errors: 0,
          avg_latency_ms: 0,
          p95_latency_ms: 0,
          p99_latency_ms: 0,
          throughput_per_sec: 0
        )
      end
    end

    it 'accepts all track methods as no-op' do
      expect { metrics.track_event_emitted(:candle) }.not_to raise_error
      expect { metrics.track_event_processed(:candle, 1.25) }.not_to raise_error
      expect { metrics.track_callback_latency(:candle, 1.25) }.not_to raise_error
      expect { metrics.track_callback_success(:candle) }.not_to raise_error
      expect { metrics.track_callback_error(:candle, StandardError.new('boom')) }.not_to raise_error
    end
  end
end
