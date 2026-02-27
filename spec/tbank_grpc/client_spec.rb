# frozen_string_literal: true

RSpec.describe TbankGrpc::Client do
  let(:client) { described_class.new }

  before do
    TbankGrpc.configure do |c|
      c.token = 'test_token'
      c.app_name = 'trddddd.tbank_grpc'
    end
  end

  after { TbankGrpc.reset_configuration }

  it 'uses global config for token and app_name' do
    expect(client.config).to include(token: 'test_token', app_name: 'trddddd.tbank_grpc')
  end

  it 'supports stream_metrics_enabled override via client config' do
    custom_client = described_class.new(stream_metrics_enabled: true)

    expect(custom_client.config[:stream_metrics_enabled]).to be(true)
    expect(custom_client.market_data_stream.metrics).to be_a(TbankGrpc::Streaming::Core::Observability::Metrics)
  ensure
    custom_client&.close
  end

  it 'exposes channel_manager' do
    expect(client.channel_manager).to be_a(TbankGrpc::ChannelManager)
  end

  it 'responds to close' do
    expect(client).to respond_to(:close)
  end

  it '#close does not raise' do
    expect { client.close }.not_to raise_error
  end

  it '#reconnect stops active stream services before rebuilding channel manager' do
    market_data_stream = instance_double(TbankGrpc::Services::MarketDataStreamService, stop_async: nil)
    client.instance_variable_set(:@market_data_stream, market_data_stream)

    client.reconnect

    expect(market_data_stream).to have_received(:stop_async)
  end

  it 'exposes #instruments as InstrumentsService' do
    channel = GRPC::Core::Channel.new('localhost:50051', {}, :this_channel_is_insecure)
    allow(client.channel_manager).to receive(:channel).and_return(channel)
    expect(client.instruments).to be_a(TbankGrpc::Services::InstrumentsService)
  end

  it 'returns same instance for #instruments' do
    channel = GRPC::Core::Channel.new('localhost:50051', {}, :this_channel_is_insecure)
    allow(client.channel_manager).to receive(:channel).and_return(channel)
    expect(client.instruments).to equal(client.instruments)
  end

  it 'exposes #users as UsersService' do
    channel = GRPC::Core::Channel.new('localhost:50051', {}, :this_channel_is_insecure)
    allow(client.channel_manager).to receive(:channel).and_return(channel)
    expect(client.users).to be_a(TbankGrpc::Services::UsersService)
  end

  it 'returns same instance for #users' do
    channel = GRPC::Core::Channel.new('localhost:50051', {}, :this_channel_is_insecure)
    allow(client.channel_manager).to receive(:channel).and_return(channel)
    expect(client.users).to equal(client.users)
  end

  it 'memoizes #users safely under concurrent access' do
    channel = GRPC::Core::Channel.new('localhost:50051', {}, :this_channel_is_insecure)
    allow(client.channel_manager).to receive(:channel).and_return(channel)

    results = Queue.new
    threads = Array.new(10) { Thread.new { results << client.users } }
    threads.each(&:join)

    instances = []
    instances << results.pop until results.empty?
    expect(instances.uniq.size).to eq(1)
  end

  it 'exposes #market_data as MarketDataService' do
    channel = GRPC::Core::Channel.new('localhost:50051', {}, :this_channel_is_insecure)
    allow(client.channel_manager).to receive(:channel).and_return(channel)
    expect(client.market_data).to be_a(TbankGrpc::Services::MarketDataService)
  end

  it 'returns same instance for #market_data' do
    channel = GRPC::Core::Channel.new('localhost:50051', {}, :this_channel_is_insecure)
    allow(client.channel_manager).to receive(:channel).and_return(channel)
    expect(client.market_data).to equal(client.market_data)
  end

  it 'exposes #operations as OperationsService' do
    channel = GRPC::Core::Channel.new('localhost:50051', {}, :this_channel_is_insecure)
    allow(client.channel_manager).to receive(:channel).and_return(channel)
    expect(client.operations).to be_a(TbankGrpc::Services::OperationsService)
  end

  it 'returns same instance for #operations' do
    channel = GRPC::Core::Channel.new('localhost:50051', {}, :this_channel_is_insecure)
    allow(client.channel_manager).to receive(:channel).and_return(channel)
    expect(client.operations).to equal(client.operations)
  end

  it 'exposes #market_data_stream as MarketDataStreamService' do
    expect(client.market_data_stream).to be_a(TbankGrpc::Services::MarketDataStreamService)
  end

  it 'returns same instance for #market_data_stream' do
    expect(client.market_data_stream).to equal(client.market_data_stream)
  end

  it 'uses dedicated channel manager for #market_data_stream' do
    expect(client.market_data_stream.channel_manager).not_to equal(client.channel_manager)
  end

  describe 'stream helper delegation' do
    let(:stream_service) { instance_double(TbankGrpc::Services::MarketDataStreamService) }

    before do
      allow(client).to receive(:market_data_stream).and_return(stream_service)
      allow(stream_service).to receive(:subscribe_orderbook)
      allow(stream_service).to receive(:subscribe_candles)
      allow(stream_service).to receive(:subscribe_trades)
      allow(stream_service).to receive(:subscribe_info)
      allow(stream_service).to receive(:subscribe_last_price)
      allow(stream_service).to receive(:listen_async)
      allow(stream_service).to receive(:listen)
      allow(stream_service).to receive(:stop_async)
      allow(stream_service).to receive(:stats).and_return({ ok: true })
      allow(stream_service).to receive(:event_stats).and_return({ candle: 1 })

      client.stream_orderbook(instrument_id: 'uid1', depth: 10, order_book_type: :ORDERBOOK_TYPE_DEALER)
      client.stream_candles(
        instrument_id: 'uid1',
        interval: :CANDLE_INTERVAL_1_MIN,
        waiting_close: true,
        candle_source_type: :CANDLE_SOURCE_EXCHANGE
      )
      client.stream_trades('uid1', trade_source: :TRADE_SOURCE_EXCHANGE, with_open_interest: true)
      client.stream_info('uid1')
      client.stream_last_price('uid1')
      client.listen_to_stream_async
      client.listen_to_stream
      client.stop_stream
      client.stream_metrics
      client.stream_event_stats(:candle)
    end

    it 'delegates stream_metrics to market_data_stream.stats' do
      expect(client.stream_metrics).to eq({ ok: true })
    end

    it 'delegates stream_event_stats to market_data_stream.event_stats' do
      expect(client.stream_event_stats(:candle)).to eq({ candle: 1 })
    end

    it 'delegates stream_orderbook to subscribe_orderbook with params' do
      expect(stream_service).to have_received(:subscribe_orderbook)
        .with(instrument_id: 'uid1', depth: 10, order_book_type: :ORDERBOOK_TYPE_DEALER)
    end

    it 'delegates stream_candles to subscribe_candles with params' do
      expect(stream_service).to have_received(:subscribe_candles).with(
        instrument_id: 'uid1',
        interval: :CANDLE_INTERVAL_1_MIN,
        waiting_close: true,
        candle_source_type: :CANDLE_SOURCE_EXCHANGE
      )
    end

    it 'delegates stream_trades to subscribe_trades with params' do
      expect(stream_service).to have_received(:subscribe_trades).with(
        'uid1',
        trade_source: :TRADE_SOURCE_EXCHANGE,
        with_open_interest: true
      )
    end

    it 'delegates stream_info to subscribe_info' do
      expect(stream_service).to have_received(:subscribe_info).with('uid1')
    end

    it 'delegates stream_last_price to subscribe_last_price' do
      expect(stream_service).to have_received(:subscribe_last_price).with('uid1')
    end

    it 'delegates listen_to_stream_async to listen_async' do
      expect(stream_service).to have_received(:listen_async)
    end

    it 'delegates listen_to_stream to listen' do
      expect(stream_service).to have_received(:listen)
    end

    it 'delegates stop_stream to stop_async' do
      expect(stream_service).to have_received(:stop_async)
    end

    it 'delegates stream_event_stats to event_stats with event type' do
      expect(stream_service).to have_received(:event_stats).with(:candle)
    end
  end

  it 'exposes #helpers as Facade' do
    expect(client.helpers).to be_a(TbankGrpc::Helpers::Facade)
  end

  it 'exposes instruments helper via #helpers' do
    expect(client.helpers.instruments).to be_a(TbankGrpc::Helpers::InstrumentsHelper)
  end

  it 'exposes market_data helper via #helpers' do
    expect(client.helpers.market_data).to be_a(TbankGrpc::Helpers::MarketDataHelper)
  end

  it 'returns same instance for #helpers' do
    expect(client.helpers).to equal(client.helpers)
  end

  context 'when token is empty' do
    before do
      TbankGrpc.configure do |c|
        c.token = ''
        c.app_name = 'trddddd.tbank_grpc'
      end
    end

    it 'raises ConfigurationError with message about token' do
      expect { described_class.new }.to raise_error(TbankGrpc::ConfigurationError, /Token is required/)
    end
  end

  context 'when app_name is empty' do
    before do
      TbankGrpc.configure do |c|
        c.token = 't'
        c.app_name = ''
      end
    end

    it 'raises ConfigurationError with message about app name' do
      expect { described_class.new }.to raise_error(TbankGrpc::ConfigurationError, /App name is required/)
    end
  end
end
