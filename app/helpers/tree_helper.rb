module TreeHelper
  # Sorts a repository's tree so that folders are before files and renders
  # their corresponding partials
  #
  # contents - A Grit::Tree object for the current tree
  def render_tree(tree)
    # Sort submodules and folders together by name ahead of files
    folders, files, submodules = tree.trees, tree.blobs, tree.submodules
    tree = ""
    items = (folders + submodules).sort_by(&:name) + files
    tree << render(partial: "projects/tree/tree_row", collection: items) if items.present?
    tree.html_safe
  end

  # Return an image icon depending on the file type and mode
  #
  # type - String type of the tree item; either 'folder' or 'file'
  # mode - File unix mode
  # name - File name
  def tree_icon(type, mode, name)
    icon("#{file_type_icon_class(type, mode, name)} fw")
  end

  def tree_hex_class(content)
    "file_#{hexdigest(content.name)}"
  end

  # Simple shortcut to File.join
  def tree_join(*args)
    File.join(*args)
  end

  def on_top_of_branch?(project = @project, ref = @ref)
    project.repository.branch_exists?(ref)
  end

  def can_edit_tree?(project = nil, ref = nil)
    project ||= @project
    ref ||= @ref

    return false unless on_top_of_branch?(project, ref)

    can_collaborate_with_project?(project)
  end

  def tree_edit_branch(project = @project, ref = @ref)
    return unless can_edit_tree?(project, ref)

    if can_push_branch?(project, ref)
      ref
    else
      project = tree_edit_project(project)
      project.repository.next_branch('patch')
    end
  end

  def tree_edit_project(project = @project)
    if can?(current_user, :push_code, project)
      project
    elsif current_user && current_user.already_forked?(project)
      current_user.fork_of(project)
    end
  end

  def edit_in_new_fork_notice_now
    "You're not allowed to make changes to this project directly." +
      " A fork of this project is being created that you can make changes in, so you can submit a merge request."
  end

  def edit_in_new_fork_notice
    "You're not allowed to make changes to this project directly." +
      " A fork of this project has been created that you can make changes in, so you can submit a merge request."
  end

  def commit_in_fork_help
    "A new branch will be created in your fork and a new merge request will be started."
  end

  def path_breadcrumbs(max_links = 6)
    if @path.present?
      part_path = ""
      parts = @path.split('/')

      yield('..', File.join(*parts.first(parts.count - 2))) if parts.count > max_links

      parts.each do |part|
        part_path = File.join(part_path, part) unless part_path.empty?
        part_path = part if part_path.empty?

        next if parts.count > max_links && !parts.last(2).include?(part)
        yield(part, part_path)
      end
    end
  end

  def up_dir_path
    file = File.join(@path, "..")
    tree_join(@ref, file)
  end

  # returns the relative path of the first subdir that doesn't have only one directory descendant
  def flatten_tree(root_path, tree)
    return tree.flat_path.sub(/\A#{root_path}\//, '') if tree.flat_path.present?

    subtree = Gitlab::Git::Tree.where(@repository, @commit.id, tree.path)
    if subtree.count == 1 && subtree.first.dir?
      return tree_join(tree.name, flatten_tree(root_path, subtree.first))
    else
      return tree.name
    end
  end
end
