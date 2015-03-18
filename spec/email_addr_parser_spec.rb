require 'spec_helper'

describe "an email address parser" do 
  
  before(:all) do
    ws             = /\s*/
    quoted_string  = ws & '"' & ARBNO(NOTANY('"\\') | '\\"' | '\\\n' | '\\\\') & '"' & ws
    atom           = ws & SPAN("\!\#\$\%\&\'\*\+\-/0123456789=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ^_`abcdefghijklmnopqrstuvwxyz{|}~") & ws
    word           = (atom | quoted_string)
    phrase         = word & ARBNO(word)
    domain_ref     = atom 
    domain_literal = "[" & /[0-9]+/ & ARBNO(/\.[0-9]+/) & "]"
    sub_domain     = domain_ref | domain_literal
    domain         = (sub_domain & ARBNO("." & sub_domain)).capture?(:domain) { |m| m.strip }
    local_part     = (word & ARBNO("." & word)).capture?(:local_part) { |m| m.strip }
    addr_spec      = (local_part & "@" & domain)
    route          = (ws & "@" & domain & ARBNO("@" & domain)).capture?(:route) { |m| m.strip } & ":" 
    route_addr     = "<" & ((route | "") & addr_spec).capture?(:mailbox) { |m| m.strip } & ">"
    mailbox        = (addr_spec.capture?(:mailbox) { |m| m.strip } | (phrase.capture?(:display_name) { |m| m.strip } & route_addr))  
    group          = (phrase.capture?(:group_name) { |m| m.strip } & ":" &
                    (( mailbox.capture?(group_mailboxes: []) & ARBNO("," & mailbox.capture?(:group_mailboxes) ) ) | ws)) & ";"
    @address       = POS(0) & (mailbox | group ) & RPOS(0)
  end
     
  it "matches a group address" do
    address = 'here is my "big fat \\\n groupen" : mitch@catprint.com, Fred Nurph<@sub1.sub2@sub3.sub4:fred.nurph@catprint.com>;'
    @address.match?(address) do |m, group_name, group_mailboxes| 
      expect(m).to be_truthy
      expect(group_name).to eq('here is my "big fat \\\n groupen"')
      expect(group_mailboxes.first.captured[:mailbox]).to eq("mitch@catprint.com")
      expect(group_mailboxes.last.captured[:mailbox]).to eq("@sub1.sub2@sub3.sub4:fred.nurph@catprint.com")
    end
  end 
  
  it "matches a simple address" do
    address = 'fred@catprint.com'
    @address.match?(address) do |
        m, 
        group_name, 
        group_mailboxes, 
        display_name, 
        mailbox, 
        local_part, 
        domain |
      expect(m).to be_truthy
      expect(group_name).to be_falsy
      expect(group_mailboxes).to be_falsy
      expect(display_name).to be_falsy
      expect(mailbox).to eq("fred@catprint.com")
      expect(local_part).to eq("fred")
      expect(domain).to eq("catprint.com")
    end
  end
  
  it "matches an address with a display_name" do
    address = 'Fred Nurph <fred@catprint.com>'
    @address.match?(address) do |
        m, 
        group_name, 
        group_mailboxes, 
        display_name, 
        mailbox, 
        local_part, 
        domain |
      expect(m).to be_truthy
      expect(group_name).to be_falsy
      expect(group_mailboxes).to be_falsy
      expect(display_name).to eq("Fred Nurph")
      expect(mailbox).to eq("fred@catprint.com")
      expect(local_part).to eq("fred")
      expect(domain).to eq("catprint.com")
    end
  end
  
  it "won't match a badly formed address" do
    address = "'Fred Nurph'<foo.com>"
    expect(@address.match?(address)).to be_falsy
  end
  
end