# Author:: Victor Costan
# Copyright:: Copyright (C) 2008 Massachusetts Institute of Technology
# License:: MIT

require 'smartcard'

require 'test/unit'

require 'rubygems'
require 'flexmock/test_unit'


class GpCardMixinTest < Test::Unit::TestCase
  GpCardMixin = Smartcard::Gp::GpCardMixin
  
  # The sole purpose of this class is wrapping the mixin under test.
  class MixinWrapper
    include GpCardMixin
  end
  
  def setup
    @file_aid = [0x19, 0x83, 0x12, 0x29, 0x10, 0xFA, 0xCE]
    @app_aid = [0x19, 0x83, 0x12, 0x29, 0x10, 0xBA, 0xBE]
    @host_auth = [0x00, 0x65, 0x07, 0x37, 0xD4, 0xB8, 0xDF, 0xDE, 0xD0, 0x7B,
                  0xAA, 0xA2, 0xDE, 0xDE, 0x82, 0x8B]    
    @host_challenge = [0x20, 0xBB, 0xE0, 0x4A, 0x1C, 0x6B, 0x6F, 0x50]
    @file_data = [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA,
                  0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x21, 0x32, 0x43, 0x54, 0x65,
                  0x76, 0x87, 0x98]
    @max_apdu_length = 0x0F
  end

  def mock_card_manager_query(channel_mock)
    flexmock(channel_mock).should_receive(:exchange_apdu).
        with([0x00, 0xA4, 0x04, 0x00, 0x00, 0x00]).
        and_return([0x6F, 16, 0x84, 8, 0xA0, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00,
                    0x00, 0xA5, 4, 0x9F, 0x65, 1, 0x0F, 0x90, 0x00])    
  end
  
  def test_gp_card_manager_aid
    mock = MixinWrapper.new
    mock_card_manager_query mock
    golden = [0xA0, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00]
    assert_equal golden, mock.gp_card_manager_aid
  end
  
  def mock_card_manager_select(channel_mock)
    flexmock(channel_mock).should_receive(:exchange_apdu).
        with([0x00, 0xA4, 0x04, 0x00, 0x08, 0xA0, 0x00, 0x00, 0x00, 0x03, 0x00,
              0x00, 0x00, 0x00]).
        and_return([0x6F, 16, 0x84, 8, 0xA0, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00,
                    0x00, 0xA5, 4, 0x9F, 0x65, 1, 0x0F, 0x90, 0x00])    
  end
    
  def test_select_application
    mock = MixinWrapper.new
    mock_card_manager_query mock
    mock_card_manager_select mock
    app_data = mock.select_application mock.gp_card_manager_aid

    golden = { :aid => mock.gp_card_manager_aid, :max_apdu_length => 0x0F }
    assert_equal golden, app_data
  end
    
  def mock_channel_setup(channel_mock)
    flexmock(channel_mock).should_receive(:exchange_apdu).
       with([0x80, 0x50, 0x00, 0x00, 0x08, 0x20, 0xBB, 0xE0, 0x4A, 0x1C, 0x6B,
             0x6F, 0x50, 0x00]).
       and_return([0x00, 0x00, 0x81, 0x29, 0x00, 0x76, 0x76, 0x91, 0x36, 0x54,
                   0xFF, 0x02, 0x00, 0x02, 0x59, 0x8D, 0xD3, 0x96, 0x1B, 0xFD,
                   0x04, 0xB5, 0xCF, 0x5A, 0xD0, 0x08, 0x3C, 0x01, 0x90, 0x00]) 
    flexmock(Smartcard::Gp::Des).should_receive(:random_bytes).with(8).
                                 and_return(@host_challenge.pack('C*'))    
  end
  
  def test_gp_setup_secure_channel
    mock = MixinWrapper.new
    mock_channel_setup mock
    golden = {
        :key_diversification => [0x00, 0x00, 0x81, 0x29, 0x00, 0x76, 0x76, 0x91,
                                 0x36, 0x54],
        :key_version => 0xFF, :protocol_id => 2, :counter => 2,
        :challenge => [0x59, 0x8D, 0xD3, 0x96, 0x1B, 0xFD],
        :auth => [0x04, 0xB5, 0xCF, 0x5A, 0xD0, 0x08, 0x3C, 0x01]
    }
    assert_equal golden, mock.gp_setup_secure_channel(@host_challenge)
  end
  
  def mock_channel_lock(channel_mock)
    flexmock(channel_mock).should_receive(:exchange_apdu).
       with([0x84, 0x82, 0x00, 0x00, 0x10, 0x00, 0x65, 0x07, 0x37, 0xD4, 0xB8,
             0xDF, 0xDE, 0xD0, 0x7B, 0xAA, 0xA2, 0xDE, 0xDE, 0x82, 0x8B, 0x00]).
       and_return([0x90, 0x00])  
  end
  
  def test_secure_channel
    mock = MixinWrapper.new
    mock_channel_setup mock
    mock_channel_lock mock

    mock.secure_channel
  end
  
  def mock_get_status_files_modules(channel_mock)
    flexmock(channel_mock).should_receive(:exchange_apdu).
        with([0x80, 0xF2, 0x10, 0x00, 0x02, 0x4F, 0x00, 0x00]).
        and_return([0x07, 0xA0, 0x00, 0x00, 0x00, 0x03, 0x53, 0x50, 0x01, 0x00,
                    0x01, 0x08, 0xA0, 0x00, 0x00, 0x00, 0x03, 0x53, 0x50, 0x41,
                    0x63, 0x10])
    flexmock(channel_mock).should_receive(:exchange_apdu).
        with([0x80, 0xF2, 0x10, 0x01, 0x02, 0x4F, 0x00, 0x00]).
        and_return([0x07, 0x19, 0x83, 0x12, 0x29, 0x10, 0xFA, 0xCE, 0x01, 0x00,
                    0x01, 0x07, 0x19, 0x83, 0x12, 0x29, 0x10, 0xBA, 0xBE, 0x90,
                    0x00])    
  end
  
  def test_gp_get_status
    mock = MixinWrapper.new
    flexmock(mock).should_receive(:exchange_apdu).once.
        with([0x80, 0xF2, 0x80, 0x00, 0x02, 0x4F, 0x00, 0x00]).
        and_return([0x08, 0xA0, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01,
                    0x9E, 0x90, 0x00])
    golden = [{ :lifecycle => :op_ready, :aid => [0xA0, 0, 0, 0, 3, 0, 0, 0],
        :permissions => Set.new([:cvm_management, :card_reset, :card_terminate,
                                 :card_lock, :security_domain]) }]
    assert_equal golden, mock.gp_get_status(:issuer_sd),
                 'Issuer security domain'
                 
    mock = MixinWrapper.new
    mock_get_status_files_modules mock
    golden = [
        { :aid => [0xA0, 0x00, 0x00, 0x00, 0x03, 0x53, 0x50],
          :permissions => Set.new, :lifecycle => :loaded,
          :modules => [
               {:aid => [0xA0, 0x00, 0x00, 0x00, 0x03, 0x53, 0x50, 0x41]}]},
        { :aid => [0x19, 0x83, 0x12, 0x29, 0x10, 0xFA, 0xCE],
          :permissions => Set.new, :lifecycle => :loaded,
          :modules => [{:aid => [0x19, 0x83, 0x12, 0x29, 0x10, 0xBA, 0xBE]}]},
    ]
  
    assert_equal golden, mock.gp_get_status(:files_modules),
                 'Executable load files and modules'
  end
  
  def test_gp_applications
    mock = MixinWrapper.new
    mock_card_manager_query mock
    mock_card_manager_select mock
    mock_channel_setup mock
    mock_channel_lock mock

    flexmock(mock).should_receive(:exchange_apdu).once.
        with([0x80, 0xF2, 0x40, 0x00, 0x02, 0x4F, 0x00, 0x00]).
        and_return([0x07, 0x19, 0x83, 0x12, 0x29, 0x10, 0xBA, 0xBE, 0x07, 0x00,
                    0x90, 0x00])
    golden = [{ :aid => @app_aid,
                :permissions => Set.new, :lifecycle => :selectable }]
    assert_equal golden, mock.applications
  end
  
  def mock_delete_file(channel_mock)
    flexmock(channel_mock).should_receive(:exchange_apdu).
       with([0x80, 0xE4, 0x00, 0x80, 0x09, 0x4F, 0x07, 0x19, 0x83, 0x12, 0x29,
             0x10, 0xFA, 0xCE, 0x00]).and_return([0x00, 0x90, 0x00])  
  end
  
  def test_gp_delete_file
    mock = MixinWrapper.new
    mock_delete_file mock
    assert_equal [], mock.gp_delete_file(@file_aid)
  end
  
  def test_delete_application
    mock = MixinWrapper.new
    mock_card_manager_query mock
    mock_card_manager_select mock
    mock_channel_setup mock
    mock_channel_lock mock
    mock_get_status_files_modules mock
    mock_delete_file mock
    
    assert mock.delete_application([0x19, 0x83, 0x12, 0x29, 0x10, 0xBA, 0xBE])
  end
  
  def test_gp_install_load
    mock = MixinWrapper.new
    mock_card_manager_query mock    
    flexmock(mock).should_receive(:exchange_apdu).
       with([0x80, 0xE6, 0x02, 0x00, 0x14, 0x07, 0x19, 0x83, 0x12, 0x29, 0x10,
             0xFA, 0xCE, 0x08, 0xA0, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00,
             0x00, 0x00, 0x00, 0x00]).and_return([0x00, 0x90, 0x00])
    assert mock.gp_install_load(@file_aid, mock.gp_card_manager_aid)
  end
  
  def test_gp_install_install
    mock = MixinWrapper.new
    flexmock(mock).should_receive(:exchange_apdu).
       with([0x80, 0xE6, 0x0C, 0x00, 0x1E, 0x07, 0x19, 0x83, 0x12, 0x29, 0x10,
             0xFA, 0xCE, 0x07, 0x19, 0x83, 0x12, 0x29, 0x10, 0xBA, 0xBE, 0x07,
             0x19, 0x83, 0x12, 0x29, 0x10, 0xBA, 0xBE, 0x01, 0x80, 0x02, 0xC9,
             0x00, 0x00, 0x00]).and_return([0x00, 0x90, 0x00])
    assert mock.gp_install_selectable(@file_aid, @app_aid, @app_aid,
                                      [:security_domain])
  end
  
  def test_gp_load_file
    mock = MixinWrapper.new
    flexmock(mock).should_receive(:exchange_apdu).
       with([0x80, 0xE8, 0x00, 0x00, 0x0A, 0xC4, 0x17, 0x11, 0x22, 0x33, 0x44,
             0x55, 0x66, 0x77, 0x88, 0x00]).and_return([0x00, 0x90, 0x00])
    flexmock(mock).should_receive(:exchange_apdu).
       with([0x80, 0xE8, 0x00, 0x01, 0x0A, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE,
             0xFF, 0x21, 0x32, 0x43, 0x00]).and_return([0x00, 0x90, 0x00])
    flexmock(mock).should_receive(:exchange_apdu).
       with([0x80, 0xE8, 0x80, 0x02, 0x05, 0x54, 0x65, 0x76, 0x87, 0x98, 0x00]).
       and_return([0x00, 0x90, 0x00])
    assert mock.gp_load_file @file_data, @max_apdu_length
  end
  
  def test_install_applet_live
    # Establish transport to live card.
    transport = Smartcard::Iso.auto_transport
    class <<transport
      include GpCardMixin      
    end
    
    # Install applet.
    applet_aid = [0x19, 0x83, 0x12, 0x29, 0x10, 0xDE, 0xAD]
    cap_file = File.join File.dirname(__FILE__), 'hello.cap'
    transport.install_applet cap_file

    # Ensure applet works.
    transport.select_application applet_aid
    assert_equal "Hello!", transport.iso_apdu!(:ins => 0x00).pack('C*')
    
    # Uninstall applet.
    transport.delete_application applet_aid
  end
end
