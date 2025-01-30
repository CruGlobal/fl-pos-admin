# lib/bootstrap_pagination_renderer.rb

class BootstrapPaginationRenderer < WillPaginate::ActionView::LinkRenderer
  protected

  def html_container(html)
    tag :nav, tag(:ul, html, class: 'pagination')
  end

  def page_number(page)
    if page == current_page
      active_class = 'active'
      link_content = tag(:span, page, class: 'page-link')
    else
      active_class = ''
      link_content = link(page, page, rel: rel_value(page), class: 'page-link')
    end

    tag :li, link_content, class: "page-item #{active_class}"
  end

  def gap
    tag :li, link('&hellip;', '#', class: 'page-link disabled'), class: 'page-item'
  end

  def previous_or_next_page(page, text, classname, *_)
    if page
      link_content = link(text, page, class: 'page-link')
      tag :li, link_content, class: "page-item #{classname}"
    else
      disabled_link = tag(:a, text, class: 'page-link disabled')
      tag :li, disabled_link, class: "page-item #{classname} disabled"
    end
  end
end
