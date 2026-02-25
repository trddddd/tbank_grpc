# frozen_string_literal: true

module LiquidityAnalyzer
  class Stats
    class RingBuffer
      attr_reader :size, :overflow_count

      def initialize(capacity)
        @capacity = capacity.to_i
        @capacity = 1 if @capacity < 1
        @buf = []
        @start = 0
        @size = 0
        @overflow_count = 0
      end

      def push(value)
        if @size < @capacity
          @buf[(@start + @size) % @capacity] = value
          @size += 1
        else
          @buf[@start] = value
          @start = (@start + 1) % @capacity
          @overflow_count += 1
        end
        self
      end

      def to_a
        (0...@size).map { |i| @buf[(@start + i) % @capacity] }
      end

      def last(count)
        to_a.last(count)
      end

      def empty?
        @size.zero?
      end
    end

    module NumericStats
      def self.median(ary)
        return nil if ary.nil? || ary.empty?

        sorted = ary.sort
        mid = sorted.length / 2
        sorted.length.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
      end

      def self.percentile(ary, percent)
        return nil if ary.nil? || ary.empty?

        percent = percent.to_f.clamp(0, 100)
        sorted = ary.sort
        return sorted[0] if sorted.size == 1

        rank = (percent / 100.0) * (sorted.size - 1)
        lo = rank.floor
        hi = rank.ceil
        return sorted[lo] if lo == hi

        weight = rank - lo
        sorted[lo] + ((sorted[hi] - sorted[lo]) * weight)
      end

      def self.stddev(ary)
        return nil if ary.nil? || ary.size < 2

        mean = ary.sum / ary.size.to_f
        variance = ary.map { |x| (x - mean)**2 }.sum / ary.size
        Math.sqrt(variance).round(4)
      end

      def self.average(ary)
        return nil if ary.nil? || ary.empty?

        ary.sum / ary.size.to_f
      end
    end

    class SlidingWindow
      attr_reader :spreads, :long, :short

      def initialize(spreads_slice, long_slice, short_slice)
        @spreads = spreads_slice.to_a
        @long = long_slice.to_a
        @short = short_slice.to_a
      end

      def size
        [@spreads.size, @long.size, @short.size].max
      end

      def empty?
        @spreads.empty? && @long.empty? && @short.empty?
      end

      def median
        {
          spread: NumericStats.median(@spreads),
          long: NumericStats.median(@long),
          short: NumericStats.median(@short),
          both: NumericStats.median(@long + @short)
        }
      end

      def percentile(percent)
        {
          spread: NumericStats.percentile(@spreads, percent),
          long: NumericStats.percentile(@long, percent),
          short: NumericStats.percentile(@short, percent),
          both: NumericStats.percentile(@long + @short, percent)
        }
      end

      def volatility
        {
          spread: NumericStats.stddev(@spreads),
          long: NumericStats.stddev(@long),
          short: NumericStats.stddev(@short),
          both: NumericStats.stddev(@long + @short)
        }
      end
    end

    class SpreadStats
      attr_reader :security

      DEFAULT_MAX_SAMPLES = 10_000

      def initialize(security:, max_samples: DEFAULT_MAX_SAMPLES)
        @security = security
        @max_samples = max_samples.to_i.positive? ? max_samples.to_i : DEFAULT_MAX_SAMPLES
        @spreads = RingBuffer.new(@max_samples)
        @long = RingBuffer.new(@max_samples)
        @short = RingBuffer.new(@max_samples)
        @mutex = Mutex.new
      end

      def buffer_info
        @mutex.synchronize do
          {
            current: [@spreads.size, @long.size, @short.size].max,
            max_samples: @max_samples,
            trim_count: @spreads.overflow_count + @long.overflow_count + @short.overflow_count,
            at_cap: at_cap?
          }
        end
      end

      def add_sample(spread_percent: nil, slippage_long: nil, slippage_short: nil)
        @mutex.synchronize do
          @spreads.push(spread_percent) if spread_percent&.positive?
          @long.push(slippage_long) if slippage_long&.positive?
          @short.push(slippage_short) if slippage_short&.positive?
        end
        self
      end

      def window(size)
        @mutex.synchronize do
          SlidingWindow.new(@spreads.last(size), @long.last(size), @short.last(size))
        end
      end

      def spread_percent_middle_value
        copy = snapshot_for_middle_values
        return nil unless copy

        compute_middle_values(copy)[:spread]
      end

      def slippage_to_long_middle_value
        copy = snapshot_for_middle_values
        return nil unless copy

        compute_middle_values(copy)[:long]
      end

      def slippage_to_short_middle_value
        copy = snapshot_for_middle_values
        return nil unless copy

        compute_middle_values(copy)[:short]
      end

      def slippage_both_value
        copy = snapshot_for_middle_values
        return nil unless copy

        compute_middle_values(copy)[:both]
      end

      private

      def at_cap?
        [@spreads.size, @long.size, @short.size].max >= @max_samples
      end

      def snapshot_for_middle_values
        @mutex.synchronize do
          return nil if @spreads.empty? && @long.empty? && @short.empty?

          { spreads: @spreads.to_a, long: @long.to_a, short: @short.to_a }
        end
      end

      def compute_middle_values(copy)
        positives = copy[:spreads].select(&:positive?)
        spread_avg = positives.any? ? NumericStats.average(positives).round(4) : nil
        long_sorted = copy[:long].select(&:positive?).sort
        short_sorted = copy[:short].select(&:positive?).sort
        both_sorted = (copy[:long] + copy[:short]).select(&:positive?).sort
        {
          spread: spread_avg,
          long: NumericStats.median(long_sorted),
          short: NumericStats.median(short_sorted),
          both: NumericStats.median(both_sorted)
        }
      end
    end
  end
end
