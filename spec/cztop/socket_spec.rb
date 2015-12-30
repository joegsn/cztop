require_relative 'spec_helper'

describe CZTop::Socket do
  include_examples "has FFI delegate"

  i = 0
  let(:endpoint) { "inproc://endpoint_socket_spec_#{i+=1}" }
  let(:req_socket) { CZTop::Socket::REQ.new(endpoint) }
  let(:rep_socket) { CZTop::Socket::REP.new(endpoint) }
  let(:binding_pair_socket) { CZTop::Socket::PAIR.new("@#{endpoint}") }
  let(:connecting_pair_socket) { CZTop::Socket::PAIR.new(">#{endpoint}") }

  it "has Zsock options" do
    assert_operator described_class, :<, CZTop::ZsockOptions
  end

  it "has send/receive methods" do
    assert_operator described_class, :<, CZTop::SendReceiveMethods
  end

  it "has polymorphic Zsock methods" do
    assert_operator described_class, :<, CZTop::PolymorphicZsockMethods
  end

  describe "#initialize" do
    context "given invalid endpoint" do
      let(:endpoint) { "foo://bar" }
      it "raises" do
        assert_raises(CZTop::InitializationError) do
          CZTop::Socket::REP.new(endpoint)
        end
      end
    end

    context "given same binding endpoint to multiple REP sockets" do
      let(:endpoint) { "inproc://the_one_and_only" }
      let(:sock1) { CZTop::Socket::REP.new(endpoint) }
      before(:each) { sock1 }
      it "raises" do
        # there can only be one REP socket bound to one endpoint
        assert_raises(CZTop::InitializationError) do
          CZTop::Socket::REP.new(endpoint)
        end
      end
    end
  end

  describe "#<< and #receive" do
    context "given a sent content" do
      let(:content) { "foobar" }
      it "receives the content" do
        connecting_pair_socket << content # REQ => REP
        msg = binding_pair_socket.receive # REQ <= REP
        assert_equal content, msg.frames.first.to_s
      end
    end
  end

  describe "#make_secure_server" do
    let(:domain) { "foo realm" }
    let(:server_certificate) { CZTop::Certificate.new }
    let(:server_skey) { server_certificate.secret_key }
    let(:options) { rep_socket.options }
    When do
      rep_socket.make_secure_server(server_skey, domain)
    end
    Then { options.curve_secretkey == server_skey }
    Then { rep_socket.options.curve_server? }
    Then { options.zap_domain == domain }
  end
  describe "#make_secure_client" do
    let(:server_certificate) { CZTop::Certificate.new }
    let(:server_public_key) { server_certificate.public_key }
    context "with client certificate" do
      let(:client_certificate) { CZTop::Certificate.new }
      let(:client_secret_key) { client_certificate.secret_key }
      before(:each) do
        req_socket.make_secure_client(client_secret_key, server_public_key)
      end

      it "sets client secret key" do
        assert_equal client_secret_key, req_socket.options.curve_secretkey
      end
#      it "sets client public key" do # TODO
#        assert_equal client_certificate.public_key,
#          req_socket.options.curve_publickey
#      end
      it "sets server's public key" do
        assert_equal server_certificate.public_key, req_socket.options.curve_serverkey
      end
      it "doesn't set CURVE server" do
        refute req_socket.options.curve_server?
      end
      it "changes mechanism to :curve" do
        assert_equal :curve, req_socket.options.mechanism
      end
    end

    # TODO: IFF certificates used directly
#    context "with incomplete certificate" do # public key only
#      it "raises"
#    end
#
#    context "with secret key in server certificate" do
#      it "raises" # server's secret key compromised
#    end
  end

  describe "#last_endpoint" do
    context "unbound socket" do
      let(:socket) { CZTop::Socket.new_by_type(:REP) }

      it "returns nil" do
        assert_nil socket.last_endpoint
      end
    end

    context "bound socket" do
      it "returns endpoint" do
        assert_equal endpoint, rep_socket.last_endpoint
      end
    end
  end

  describe "#connect" do
    Given(:socket) { rep_socket }
    context "with valid endpoint" do
      let(:another_endpoint) { "inproc://foo" }
      it "connects" do
        req_socket.connect(another_endpoint)
      end
    end
    context "with invalid endpoint" do
      Given(:another_endpoint) { "foo://bar" }
      When(:result) { socket.connect(another_endpoint) }
      Then { result == Failure(ArgumentError) }
    end
    it "does safe format handling" do
      expect(socket.ffi_delegate).to receive(:connect).with("%s", any_args).and_return(0)
      socket.connect(double("endpoint"))
    end
  end

  describe "#disconnect" do
    Given(:socket) { rep_socket }
    context "with valid endpoint" do
      it "disconnects" do
        expect(socket.ffi_delegate).to receive(:disconnect)
        socket.disconnect(endpoint)
      end
    end
    context "with invalid endpoint" do
      Given(:another_endpoint) { "foo://bar" }
      When(:result) { socket.disconnect(another_endpoint) }
      Then { result == Failure(ArgumentError) }
    end
    it "does safe format handling" do
      expect(socket.ffi_delegate).to receive(:disconnect).with("%s", any_args).and_return(0)
      socket.disconnect(double("endpoint"))
    end
  end

  describe "#bind" do
    Given(:socket) { rep_socket }
    context "with valid endpoint" do
      Then { assert_nil socket.last_tcp_port }
      context "with automatic TCP port selection endpoint" do
        Given(:another_endpoint) { "tcp://127.0.0.1:*" }
        When { socket.bind(another_endpoint) }
        Then { assert_kind_of Integer, socket.last_tcp_port }
        And { socket.last_tcp_port > 0 }
      end
      context "with explicit TCP port endpoint" do
        Given(:port) { rand(55_755..58_665) }
        Given(:another_endpoint) { "tcp://127.0.0.1:#{port}" }
        When { socket.bind(another_endpoint) }
        Then { socket.last_tcp_port == port }
      end
      context "with non-TCP endpoint" do
        Given(:another_endpoint) { "inproc://non_tcp_endpoint" }
        When { socket.bind(another_endpoint) }
        Then { assert_nil socket.last_tcp_port }
      end
    end
    context "with invalid endpoint" do
      Given(:another_endpoint) { "foo://bar" }
      When(:result) { socket.bind(another_endpoint) }
      Then { result == Failure(CZTop::Socket::Error) }
    end

    it "does safe format handling" do
      expect(socket.ffi_delegate).to receive(:bind).with("%s", any_args).and_return(0)
      socket.bind(double("endpoint"))
    end
  end

  describe "#unbind" do
    Given(:socket) { rep_socket }
    context "with valid endpoint" do
      it "unbinds" do
        expect(socket.ffi_delegate).to receive(:unbind)
        socket.unbind(endpoint)
      end
    end
    context "with invalid endpoint" do
      Given(:another_endpoint) { "bar://foo" }
      When(:result) { socket.unbind(another_endpoint) }
      Then { result == Failure(ArgumentError) }
    end
    it "does safe format handling" do
      expect(socket.ffi_delegate).to receive(:unbind).with("%s", any_args).and_return(0)
      socket.unbind(double("endpoint"))
    end
  end
end
