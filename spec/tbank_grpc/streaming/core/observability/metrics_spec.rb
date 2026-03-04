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

  describe 'memory bounds' do
    it 'caps latency history at max_latency_samples per event type' do
      metrics = described_class.new(enabled: true, max_latency_samples: 5)
      10.times { |i| metrics.track_event_processed(:candle, i + 1.0) }

      stats = metrics.event_stats(:candle)
      expect(stats[:processed]).to eq(10)
      # Only last 5 latencies kept for percentiles/avg
      expect(metrics.to_h[:latency_stats][:candle][:count]).to eq(5)
    end

    it 'caps error history at max_errors_per_type' do
      metrics = described_class.new(enabled: true, max_errors_per_type: 3)
      5.times { |i| metrics.track_callback_error(:candle, StandardError.new("e#{i}")) }

      expect(metrics.to_h[:error_count]).to eq(3)
    end

    it 'prunes errors by TTL when error_ttl_seconds is set' do
      metrics = described_class.new(enabled: true, max_errors_per_type: 10, error_ttl_seconds: 0.2)
      metrics.track_callback_error(:candle, StandardError.new('old'))
      sleep 0.25
      metrics.track_callback_error(:candle, StandardError.new('new'))

      expect(metrics.to_h[:error_count]).to eq(1)
    end
  end

  describe '#reset_aggregates!' do
    it 'zeros counters and clears history, resets started_at by default' do
      metrics = described_class.new(enabled: true)
      metrics.track_event_emitted(:candle)
      metrics.track_event_processed(:candle, 1.0)
      metrics.track_callback_success(:candle)

      metrics.reset_aggregates!

      expect(metrics.to_h[:events_emitted]).to eq({})
      expect(metrics.to_h[:events_processed]).to eq({})
      expect(metrics.event_stats(:candle)[:emitted]).to eq(0)
      expect(metrics.to_h[:uptime_seconds]).to be >= 0
    end

    it 'does nothing when enabled: false' do
      metrics = described_class.new(enabled: false)
      expect { metrics.reset_aggregates! }.not_to raise_error
    end
  end
end
