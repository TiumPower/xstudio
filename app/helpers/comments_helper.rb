module CommentsHelper
  def comments_dom_id(commentable)
    "comments_#{commentable.class.name.underscore}_#{commentable.id}"
  end

  def mentionable_people_json
    User.assignable.map { |u| { id: u.id, name: u.display_name } }.to_json
  end

  # Biến @[Tên](id) thành chip nhắc tên khi hiển thị.
  def highlight_mentions(body)
    escaped = ERB::Util.html_escape(body.to_s)
    escaped.gsub(Comments::ProcessMentions::PATTERN) do
      name = Regexp.last_match[:name]
      %(<span class="x-chip x-chip-brand" style="padding:1px 7px">@#{ERB::Util.html_escape(name)}</span>)
    end.html_safe
  end
end
