require 'spec_helper'

describe 'allow_agent_classes', :type => :class do
  context "Adding test_class" do
    let :facts do
      {
        :add_classes => 'test_class'
      }
    end
    it { is_expected.to contain_class("allow_agent_classes") }
    it { is_expected.to contain_class("test_class") }
  end
end
