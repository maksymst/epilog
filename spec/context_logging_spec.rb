# frozen_string_literal: true

# rubocop:disable BlockLength
RSpec.describe Epilog::ContextLogger do
  let(:formatter_class) do
    Class.new(::Logger::Formatter) do
      def call(*)
        "#{JSON.dump(@context)}\n"
      end

      def push_context(context)
        @context = context
      end

      def pop_context
        @context = nil
      end
    end
  end

  let(:logger_class) do
    Class.new(::Logger) do
      include Epilog::ContextLogger
    end
  end

  subject do
    logger = logger_class.new(output)
    logger.formatter = formatter
    logger
  end
  let(:formatter) { formatter_class.new }
  let(:output) { StringIO.new }

  it 'temporarily adds context to the formatter' do
    subject.with_context(user_id: 123) do
      subject.info('hi')
    end

    subject.info('done')

    output.rewind
    expect(output.read).to eq(
      <<~LOG
        {"user_id":123}
        null
      LOG
    )
  end
end

RSpec.describe Epilog::ContextFormatter do
  let(:formatter_class) do
    Class.new(::Logger::Formatter) do
      include Epilog::ContextFormatter

      def call(*)
        context
      end
    end
  end

  subject { formatter_class.new }

  it 'pushes context on the stack' do
    subject.push_context(user_id: 123)
    expect(subject.call).to eq(user_id: 123)
  end

  it 'merges multiple context frames' do
    subject.push_context(user_id: 123)
    subject.push_context(admin_id: 99)
    expect(subject.call).to eq(user_id: 123, admin_id: 99)
    subject.pop_context
    expect(subject.call).to eq(user_id: 123)
  end

  it 'starts with empty context' do
    expect(subject.call).to eq({})
  end

  it 'has empty context if all frames are popped' do
    subject.push_context(user_id: 123)
    subject.push_context(admin_id: 99)
    subject.pop_context
    subject.pop_context
    expect(subject.call).to eq({})
  end
end
# rubocop:enable BlockLength
