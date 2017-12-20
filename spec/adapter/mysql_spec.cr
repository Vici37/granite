require "./spec_helper"
require "../src/adapter/mysql"

class Owner < Granite::ORM::Base
  adapter mysql

  has_many :posts
  has_many :groups, through: :posts

  field name : String
  timestamps
end

class Post < Granite::ORM::Base
  adapter mysql

  belongs_to :owner
  belongs_to :group

  field name : String
  field body : String
  field total : Int32
  field slug : String
  timestamps
end

class Group < Granite::ORM::Base
  adapter mysql

  has_many :posts
  has_many :owners, through: :posts

  field name : String
end

class Site < Granite::ORM::Base
  adapter mysql
  primary custom_id : Int32
  field name : String
end

class Chat::Room < Granite::ORM::Base
  adapter mysql
  field name : String
end

Owner.exec("DROP TABLE IF EXISTS owners;")
Owner.exec("CREATE TABLE owners (
  id BIGINT NOT NULL AUTO_INCREMENT,
  name VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY(id)
);
")

Post.exec("DROP TABLE IF EXISTS posts;")
Post.exec("CREATE TABLE posts (
  id BIGINT NOT NULL AUTO_INCREMENT,
  name VARCHAR(255),
  body TEXT,
  total INTEGER,
  owner_id BIGINT,
  group_id BIGINT,
  slug VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
);
")

Group.exec("DROP TABLE IF EXISTS groups;")
Group.exec("CREATE TABLE groups (
  id BIGINT NOT NULL AUTO_INCREMENT,
  name VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY(id)
);
")

Site.exec("DROP TABLE IF EXISTS sites;")
Site.exec("CREATE TABLE sites (
  custom_id INT(11) NOT NULL AUTO_INCREMENT,
  name VARCHAR(255),
  PRIMARY KEY (custom_id)
);
")

Chat::Room.exec("DROP TABLE IF EXISTS chat_rooms;")
Chat::Room.exec("CREATE TABLE chat_rooms (
  id BIGINT NOT NULL AUTO_INCREMENT,
  name VARCHAR(255),
  PRIMARY KEY (id)
);
")

describe Granite::Adapter::Mysql do
  Spec.before_each do
    Owner.clear
    Post.clear
    Site.clear
  end

  describe "#belongs_to" do
    it "provides a method to retrieve parent" do
      owner = Owner.new
      owner.name = "Test Owner"
      owner.save

      post = Post.new
      post.name = "Test Post"
      post.owner_id = owner.id
      post.save

      post.owner.name.should eq "Test Owner"
    end

    it "provides a method to set parent" do
      owner = Owner.new
      owner.name = "Test Owner"
      owner.save

      post = Post.new
      post.name = "Test Post"
      post.owner = owner
      post.save

      post.owner_id.should eq owner.id
    end
  end

  describe "#has_many" do
    it "provides a method to retrieve children" do
      owner = Owner.new
      owner.name = "Test Owner"
      owner.save

      post = Post.new
      post.name = "Test Post 1"
      post.owner = owner
      post.save
      post = Post.new
      post.name = "Test Post 2"
      post.owner = owner
      post.save
      post = Post.new
      post.name = "Test Post 3"
      post.save

      owner.posts.size.should eq 2
    end
  end

  describe "#has_many, through:" do
    it "provides a method to retrieve children through another table" do
      owner = Owner.new
      owner.name = "Test Owner"
      owner.save

      group = Group.new
      group.name = "Test Group"
      group.save

      post = Post.new
      post.name = "Test Post 1"
      post.owner = owner
      post.group = group
      post.save
      post = Post.new
      post.name = "Test Post 2"
      post.owner = owner
      post.group = group
      post.save
      post = Post.new
      post.name = "Test Post 3"
      post.owner = owner
      post.save

      owner.groups.size.should eq 2
      group.posts.size.should eq 2
    end
  end

  describe "#destroy" do
    it "destroys a post" do
      post = Post.new
      post.name = "Test Post"
      post.save
      id = post.id
      post.destroy
      post = Post.find id
      post.should be_nil
    end
  end

  describe "Site model with custom primary key" do
    describe "#find" do
      it "finds the site by custom_id" do
        site = Site.new
        site.name = "Test Site"
        site.save
        pk = site.custom_id
        site = Site.find pk
        site.should_not be_nil
      end
    end

    describe "#save" do
      it "updates an existing site" do
        site = Site.new
        site.name = "Test Site"
        site.save
        site.name = "Test Site 2"
        site.save
        site = Site.find 1
        if site
          site.name.should eq "Test Site 2"
        end
      end
    end

    describe "#destroy" do
      it "destroys a site" do
        site = Site.new
        site.name = "Test Site"
        site.save
        pk = site.custom_id
        site.destroy
        site = Site.find pk
        site.should be_nil
      end
    end
  end

  describe "Chat::Room using module" do
    Spec.before_each do
      Chat::Room.clear
    end

    describe "#find" do
      it "finds the Chat::Room" do
        chat_room = Chat::Room.new
        chat_room.name = "Test Room"
        chat_room.save
        pk = chat_room.id
        chat_room = Chat::Room.find pk
        chat_room.should_not be_nil
      end
    end

    describe "#save" do
      it "updates an existing Chat::Room" do
        chat_room = Chat::Room.new
        chat_room.name = "Test Site"
        chat_room.save
        chat_room.name = "Test Site 2"
        chat_room.save
        chat_room = Chat::Room.find 1
        if chat_room
          chat_room.name.should eq "Test Site 2"
        end
      end
    end

    describe "#destroy" do
      it "destroys a Chat::Room" do
        chat_room = Chat::Room.new
        chat_room.name = "Test Site"
        chat_room.save
        pk = chat_room.id
        chat_room.destroy
        chat_room = Site.find pk
        chat_room.should be_nil
      end
    end
  end

  describe "timestamps" do
    it "uses UTC for created_at" do
      role = Owner.new(name: "test").tap(&.save)
      same_role = Owner.find(role.id).not_nil!

      original_timestamp = role.created_at.not_nil!
      read_timestamp = same_role.created_at.not_nil!

      original_timestamp.kind.should eq Time::Kind::Utc
      read_timestamp.kind.should eq Time::Kind::Unspecified
    end

    it "uses UTC for updated_at" do
      role = Owner.new(name: "test").tap(&.save)
      same_role = Owner.find(role.id).not_nil!

      original_timestamp = role.updated_at.not_nil!
      read_timestamp = same_role.updated_at.not_nil!

      original_timestamp.kind.should eq Time::Kind::Utc
      read_timestamp.kind.should eq Time::Kind::Unspecified
    end

    it "truncates the subsecond parts of created_at" do
      role = Owner.new(name: "test").tap(&.save)
      same_role = Owner.find(role.id).not_nil!

      original_timestamp = role.created_at.not_nil!
      read_timestamp = same_role.created_at.not_nil!
      hacked_timestamp = Time.new(read_timestamp.ticks, kind: Time::Kind::Utc)

      original_timestamp.epoch_f.to_i.should eq hacked_timestamp.epoch
    end

    it "truncates the subsecond parts of updated_at" do
      role = Owner.new(name: "test").tap(&.save)

      original_timestamp = role.updated_at.not_nil!
      same_role = Owner.find(role.id).not_nil!
      read_timestamp = same_role.updated_at.not_nil!
      hacked_timestamp = Time.new(read_timestamp.ticks, kind: Time::Kind::Utc)

      original_timestamp.epoch_f.to_i.should eq hacked_timestamp.epoch
    end
  end
end
