require 'spec_helper'

describe Bosh::Monitor::TcpConnection do
  describe 'exponential back off' do
    context 'when the initial connection fails' do
      let(:tcp_connection) { Bosh::Monitor::TcpConnection.new('connection.tcp', '127.0.0.1', 80, Bhm::TcpConnection::DEFAULT_RETRIES) }

      before do
        Bhm.logger = logger
        allow(tcp_connection).to receive(:retry_reconnect)
      end

      it 'tries to reconnect when unbinding' do
        expect(tcp_connection).to receive(:retry_reconnect).with(0)
        tcp_connection.unbind
      end

      it "doesn't log on the first unbind" do
        expect(logger).to_not receive(:info)
        tcp_connection.unbind
      end

      it 'logs on subsequent unbinds' do
        tcp_connection.unbind
        expect(logger).to receive(:info).with('connection.tcp-failed-to-reconnect, will try again in 1 seconds...')
        tcp_connection.unbind
      end

      it 'takes exponentially longer' do
        expect(tcp_connection).to receive(:retry_reconnect).with(0)
        tcp_connection.unbind
        expect(tcp_connection).to receive(:retry_reconnect).with(1)
        tcp_connection.unbind
        expect(tcp_connection).to receive(:retry_reconnect).with(3)
        tcp_connection.unbind
      end

      it 'should exit after MAX_RETRIES retries' do
        expect do
          (Bhm::TcpConnection::DEFAULT_RETRIES + 1).times do
            tcp_connection.unbind
          end
        end.to raise_error(/connection.tcp-failed-to-reconnect after/)
      end

      context 'when max_retries is infinite' do
        let(:tcp_connection) { Bosh::Monitor::TcpConnection.new('connection.tcp', '127.0.0.1', 80, -1) }

        it 'should try "indefinitely"' do
          expect(tcp_connection).to receive(:retry_reconnect).at_least(Bhm::TcpConnection::DEFAULT_RETRIES + 5).times

          expect do
            (Bhm::TcpConnection::DEFAULT_RETRIES + 5).times do
              tcp_connection.unbind
            end
          end.to_not raise_error
        end
      end
    end
  end
end
