require "test_helper"

class TestRegistration < DiscoverIntegrationTest
  class TestRegisterStandby
    include Celluloid

    def initialize(client, name, port, ip)
      @client  = client
      @name    = name
      @port    = port
      @ip      = ip
      @elected = false

      async.register_and_standby
    end

    def elected?
      @elected
    end

    def register_and_standby
      @client.register_and_standby(@name, @port, @ip)

      @elected = true
    end
  end

  def test_service_is_online_after_registration
    name       = "foo"
    port       = 1111
    ip         = "127.0.0.1"
    attributes = { "foo" => "bar" }

    @client.register name, port, ip, attributes

    service = @client.service(name)
    assert_equal 1, service.online.size

    instance = service.online.first
    assert_equal name, instance.name
    assert_equal "#{ip}:#{port}", instance.address
    assert_equal attributes, instance.attributes
    assert instance.online?

    sleep(11)
    assert_equal 1, service.online.size
  end

  def test_service_is_offline_after_unregister
    name       = "foo"
    port       = 1111
    ip         = "127.0.0.1"

    registration = @client.register name, port, ip

    service = @client.service(name)
    assert_equal 1, service.online.size

    registration.unregister

    service = @client.service(name)
    assert_equal 0, service.online.size
  end

  def test_changing_service_attributes
    name       = "foo"
    port       = 1111
    ip         = "127.0.0.1"
    attributes = { "foo" => "bar" }

    @client.register name, port, ip, attributes

    service = @client.service(name)
    assert_equal 1, service.online.size

    instance = service.online.first
    assert_equal attributes, instance.attributes

    new_attributes = { "foo" => "baz" }
    @client.register name, port, ip, new_attributes

    service = @client.service(name)
    assert_equal 1, service.online.size

    instance = service.online.first
    assert_equal new_attributes, instance.attributes
  end

  def test_service_with_filters
    name = "foo"
    ip   = "127.0.0.1"

    matching_attributes     = { "foo" => "bar", "baz" => "qux" }
    non_matching_attributes = { "foo" => "baz", "baz" => "qux" }

    @client.register name, 1111, ip, matching_attributes
    @client.register name, 2222, ip, non_matching_attributes

    service = @client.service(name)
    assert_equal 2, service.online.size

    filtered_service = @client.service(name, "foo" => "bar")
    assert_equal 1, filtered_service.online.size

    instance = filtered_service.online.first
    assert_equal matching_attributes, instance.attributes
  end

  def test_register_and_standby
    name = "foo"
    ip   = "127.0.0.1"

    registrations = []
    registrations << @client.register(name, 1111, ip)

    standby = TestRegisterStandby.new @client, name, 2222, ip
    sleep(0.2)
    assert !standby.elected?

    registrations << @client.register(name, 3333, ip)
    sleep(0.2)
    assert !standby.elected?

    registrations.each(&:unregister)
    sleep(0.2)
    assert standby.elected?
  end
end
