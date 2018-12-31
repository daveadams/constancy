# This software is public domain. No rights are reserved. See LICENSE for more information.

require 'spec_helper'

class MockTarget
  attr_reader :base_path, :exclude, :prefix, :type, :description
  def initialize(delete: true, prefix: "config", type: :dir, exclude: [], base_path: "", description: "mock-target")
    @delete = delete
    @prefix = prefix
    @exclude = exclude
    @base_path = base_path
    @description = description
    @type = type
  end

  def delete?
    @delete
  end
end

RSpec.describe Constancy::Diff do
  let(:default_target) { MockTarget.new }
  let(:sets) {
    {
      empty: {},
      base: {
        "abc" => "hello world",
        "xyz/qux" => "You've got mail.",
      },
      deletion: {
        "xyz/qux" => "You've got mail.",
      },
      addition: {
        "abc" => "hello world",
        "mno" => "whatevs",
        "xyz/qux" => "You've got mail.",
      },
      update: {
        "abc" => "goodbye world",
        "xyz/qux" => "You've got mail.",
      },
      multi_change: {
        "mno" => "banana",
        "xyz/qux" => "You've got no mail.",
      },
    }
  }

  let(:push_no_changes) {
    Constancy::Diff.new(
      target: default_target,
      local: sets[:base],
      remote: sets[:base],
      mode: :push,
    )
  }

  let(:push_create_one) {
    Constancy::Diff.new(
      target: default_target,
      local: sets[:addition],
      remote: sets[:base],
      mode: :push,
    )
  }

  let(:push_create_many) {
    Constancy::Diff.new(
      target: default_target,
      local: sets[:addition],
      remote: sets[:empty],
      mode: :push,
    )
  }

  let(:push_update_one) {
    Constancy::Diff.new(
      target: default_target,
      local: sets[:update],
      remote: sets[:base],
      mode: :push,
    )
  }

  let(:push_delete_one) {
    Constancy::Diff.new(
      target: default_target,
      local: sets[:deletion],
      remote: sets[:base],
      mode: :push,
    )
  }

  let(:push_delete_all) {
    Constancy::Diff.new(
      target: default_target,
      local: sets[:empty],
      remote: sets[:base],
      mode: :push,
    )
  }

  let(:push_multi_change) {
    Constancy::Diff.new(
      target: default_target,
      local: sets[:multi_change],
      remote: sets[:base],
      mode: :push,
    )
  }

  let(:pull_no_changes) {
    Constancy::Diff.new(
      target: default_target,
      local: sets[:base],
      remote: sets[:base],
      mode: :push,
    )
  }

  let(:pull_create_one) {
    Constancy::Diff.new(
      target: default_target,
      local: sets[:base],
      remote: sets[:addition],
      mode: :pull,
    )
  }

  let(:pull_create_many) {
    Constancy::Diff.new(
      target: default_target,
      local: sets[:empty],
      remote: sets[:addition],
      mode: :pull,
    )
  }

  let(:pull_update_one) {
    Constancy::Diff.new(
      target: default_target,
      local: sets[:base],
      remote: sets[:update],
      mode: :pull,
    )
  }

  let(:pull_delete_one) {
    Constancy::Diff.new(
      target: default_target,
      local: sets[:base],
      remote: sets[:deletion],
      mode: :pull,
    )
  }

  let(:pull_delete_all) {
    Constancy::Diff.new(
      target: default_target,
      local: sets[:base],
      remote: sets[:empty],
      mode: :pull,
    )
  }

  let(:pull_multi_change) {
    Constancy::Diff.new(
      target: default_target,
      local: sets[:base],
      remote: sets[:multi_change],
      mode: :pull,
    )
  }

  describe '#items_to_create' do
    it 'must recognize created items' do
      expect(push_create_one.items_to_create.collect(&:relative_path).sort).to eq (sets[:addition].keys - sets[:base].keys).sort
      expect(pull_create_one.items_to_create.collect(&:relative_path).sort).to eq (sets[:addition].keys - sets[:base].keys).sort

      expect(push_create_many.items_to_create.collect(&:relative_path).sort).to eq sets[:addition].keys.sort
      expect(pull_create_many.items_to_create.collect(&:relative_path).sort).to eq sets[:addition].keys.sort
    end

    it 'must recognize when no items are created' do
      expect(push_update_one.items_to_create).to eq []
      expect(pull_update_one.items_to_create).to eq []

      expect(push_no_changes.items_to_create).to eq []
      expect(pull_no_changes.items_to_create).to eq []
    end
  end

  describe '#items_to_delete' do
    it 'must recognize deleted items' do
      expect(push_delete_one.items_to_delete.collect(&:relative_path).sort).to eq (sets[:base].keys - sets[:deletion].keys).sort
      expect(pull_delete_one.items_to_delete.collect(&:relative_path).sort).to eq (sets[:base].keys - sets[:deletion].keys).sort

      expect(push_delete_all.items_to_delete.collect(&:relative_path).sort).to eq sets[:base].keys.sort
      expect(pull_delete_all.items_to_delete.collect(&:relative_path).sort).to eq sets[:base].keys.sort
    end

    it 'must recognize when no items are deleted' do
      expect(push_update_one.items_to_delete).to eq []
      expect(pull_update_one.items_to_delete).to eq []

      expect(push_no_changes.items_to_delete).to eq []
      expect(pull_no_changes.items_to_delete).to eq []
    end
  end

  describe '#items_to_update' do
    it 'must recognize updated items' do
      expect(push_update_one.items_to_update.collect(&:relative_path).sort).to eq ["abc"]
      expect(pull_update_one.items_to_update.collect(&:relative_path).sort).to eq ["abc"]
    end

    it 'must recognize when no items are updated' do
      expect(push_no_changes.items_to_update).to eq []
      expect(pull_no_changes.items_to_update).to eq []

      expect(push_delete_one.items_to_update).to eq []
      expect(pull_delete_one.items_to_update).to eq []
    end
  end

  describe '#any_changes?' do
    it 'must recognize changes' do
      expect(push_update_one.any_changes?).to eq true
      expect(pull_multi_change.any_changes?).to eq true
    end

    it 'must recognize when no changes have been made' do
      expect(push_no_changes.any_changes?).to eq false
      expect(pull_no_changes.any_changes?).to eq false
    end
  end
end
