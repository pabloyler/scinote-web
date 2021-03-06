class RepositoryRowsController < ApplicationController
  include InputSanitizeHelper
  include ActionView::Helpers::TextHelper
  include ApplicationHelper
  include MyModulesHelper

  before_action :load_repository
  before_action :load_repository_row, only: %i(update show assigned_task_list)
  before_action :check_read_permissions, except: %i(create update delete_records copy_records)
  before_action :check_snapshotting_status, only: %i(create update delete_records copy_records)
  before_action :check_create_permissions, only: :create
  before_action :check_delete_permissions, only: :delete_records
  before_action :check_manage_permissions, only: %i(update copy_records)

  def index
    @draw = params[:draw].to_i
    per_page = params[:length] == '-1' ? 100 : params[:length].to_i
    page = (params[:start].to_i / per_page) + 1
    datatable_service = RepositoryDatatableService.new(@repository, params, current_user)

    @all_rows_count = datatable_service.all_count
    @columns_mappings = datatable_service.mappings
    @repository_rows = datatable_service.repository_rows
                                        .preload(:repository_columns,
                                                 :created_by,
                                                 repository_cells: @repository.cell_preload_includes)
                                        .page(page)
                                        .per(per_page)
  end

  def create
    service = RepositoryRows::CreateRepositoryRowService
              .call(repository: @repository, user: current_user, params: update_params)

    if service.succeed?
      repository_row = service.repository_row
      log_activity(:create_item_inventory, repository_row)
      repository_row.repository_cells.where(value_type: 'RepositoryTextValue').each do |repository_cell|
        record_annotation_notification(repository_row, repository_cell)
      end

      render json: { id: service.repository_row.id, flash: t('repositories.create.success_flash',
                                                             record: escape_input(repository_row.name),
                                                             repository: escape_input(@repository.name)) },
             status: :ok
    else
      render json: service.errors, status: :bad_request
    end
  end

  def show
    @assigned_modules = @repository_row.my_modules.joins(experiment: :project)
    @viewable_modules = @assigned_modules.viewable_by_user(current_user, current_user.teams)
    @private_modules = @assigned_modules - @viewable_modules

    respond_to do |format|
      format.json do
        render json: {
          html: render_to_string(
            partial: 'repositories/repository_row_info_modal.html.erb'
          )
        }
      end
    end
  end

  def update
    row_update = RepositoryRows::UpdateRepositoryRowService
                 .call(repository_row: @repository_row, user: current_user, params: update_params)

    if row_update.succeed?
      if row_update.record_updated
        log_activity(:edit_item_inventory, @repository_row)
        @repository_row.repository_cells.where(value_type: 'RepositoryTextValue').each do |repository_cell|
          record_annotation_notification(@repository_row, repository_cell)
        end
      end

      render json: {
        id: @repository_row.id,
        flash: t(
          'repositories.update.success_flash',
          record: escape_input(@repository_row.name),
          repository: escape_input(@repository.name)
        )
      }, status: :ok
    else
      render json: row_update.errors, status: :bad_request
    end
  end

  def delete_records
    deleted_count = 0
    if selected_params
      selected_params.each do |row_id|
        row = @repository.repository_rows.find_by(id: row_id)
        next unless row && can_manage_repository_rows?(@repository)

        log_activity(:delete_item_inventory, row)
        row.destroy && deleted_count += 1
      end
      if deleted_count.zero?
        flash = t('repositories.destroy.no_deleted_records_flash',
                  other_records_number: selected_params.count)
      elsif deleted_count != selected_params.count
        not_deleted_count = selected_params.count - deleted_count
        flash = t('repositories.destroy.contains_other_records_flash',
                  records_number: deleted_count,
                  other_records_number: not_deleted_count)
      else
        flash = t('repositories.destroy.success_flash',
                  records_number: deleted_count)
      end
      respond_to do |format|
        color = deleted_count.zero? ? 'info' : 'success'
        format.json { render json: { flash: flash, color: color }, status: :ok }
      end
    else
      respond_to do |format|
        format.json do
          render json: {
            flash: t('repositories.destroy.no_records_selected_flash')
          }, status: :bad_request
        end
      end
    end
  end

  def copy_records
    duplicate_service = RepositoryActions::DuplicateRows.new(
      current_user, @repository, copy_records_params
    )
    duplicate_service.call
    render json: {
      flash: t('repositories.copy_records_report',
               number: duplicate_service.number_of_duplicated_items)
    }, status: :ok
  end

  def available_rows
    if @repository.repository_rows.empty?
      no_items_string =
        "#{t('projects.reports.new.save_PDF_to_inventory_modal.no_items')} " \
        "#{link_to(t('projects.reports.new.save_PDF_to_inventory_modal.here'),
                   repository_path(@repository),
                   data: { 'no-turbolink' => true })}"
      render json: { no_items: no_items_string },
                   status: :ok
    else
      render json: { results: load_available_rows(search_params[:q]) },
                   status: :ok
    end
  end

  def assigned_task_list
    assigned_modules = @repository_row.my_modules.joins(experiment: :project)
    viewable_modules = assigned_modules.viewable_by_user(current_user, current_user.teams)
    private_modules = assigned_modules - viewable_modules

    viewable_modules = viewable_modules.where_attributes_like(
      ['my_modules.name', 'experiments.name', 'projects.name'],
      params[:query],
      whole_phrase: true
    )
    render json: {
      html: render_to_string(partial: 'shared/my_modules_list_partial.html.erb', locals: {
                               my_modules: viewable_modules,
                               private_modules: private_modules
                             })
    }
  end

  private

  include StringUtility
  AvailableRepositoryRow = Struct.new(:id, :name, :has_file_attached)

  def load_repository
    @repository = Repository.accessible_by_teams(current_team)
                            .eager_load(:repository_columns)
                            .find_by(id: params[:repository_id])
    render_404 unless @repository
  end

  def load_repository_row
    @repository_row = @repository.repository_rows.eager_load(:repository_columns).find_by(id: params[:id])
    render_404 unless @repository_row
  end

  def check_read_permissions
    render_403 unless can_read_repository?(@repository)
  end

  def check_snapshotting_status
    return if @repository.repository_snapshots.provisioning.none?

    respond_to do |format|
      format.json do
        render json: {
          flash: t('repositories.index.snapshot_provisioning_in_progress')
        }, status: :unprocessable_entity
      end
    end
  end

  def check_create_permissions
    render_403 unless can_create_repository_rows?(@repository)
  end

  def check_manage_permissions
    render_403 unless can_manage_repository_rows?(@repository)
  end

  def check_delete_permissions
    render_403 unless can_delete_repository_rows?(@repository)
  end

  def remove_file_columns_params
    JSON.parse(params.fetch(:remove_file_columns) { '[]' })
  end

  def selected_params
    params.permit(selected_rows: []).to_h[:selected_rows]
  end

  def copy_records_params
    process_ids = params[:selected_rows].map(&:to_i).uniq
    @repository.repository_rows.where(id: process_ids).pluck(:id)
  end

  def load_available_rows(query)
    @repository.repository_rows
               .includes(:repository_cells)
               .name_like(search_params[:q])
               .limit(Constants::SEARCH_LIMIT)
               .select(:id, :name)
               .collect do |row|
                 with_asset_cell = row.repository_cells.where(
                   'repository_cells.repository_column_id = ?',
                   search_params[:repository_column_id]
                 )
                 AvailableRepositoryRow.new(row.id,
                                            ellipsize(row.name, 75, 50),
                                            with_asset_cell.present?)
               end
  end

  def search_params
    params.permit(:q, :repository_id, :repository_column_id)
  end

  def record_annotation_notification(record, cell, old_text = nil)
    smart_annotation_notification(
      old_text: old_text,
      new_text: cell.value.data,
      title: t('notifications.repository_annotation_title',
               user: current_user.full_name,
               column: cell.repository_column.name,
               record: record.name,
               repository: record.repository.name),
      message: t('notifications.repository_annotation_message_html',
                 record: link_to(record.name, repository_url(@repository)),
                 column: link_to(cell.repository_column.name, repository_url(@repository)))
    )
  end

  def fetch_list_items(cell)
    return [] if cell.value_type != 'RepositoryListValue'
    RepositoryListItem.where(repository: @repository)
                      .where(repository_column: cell.repository_column)
                      .limit(Constants::SEARCH_LIMIT)
                      .pluck(:id, :data)
                      .map { |li| [li[0], escape_input(li[1])] }
  end

  def fetch_columns_list_items
    collection = []
    @repository.repository_columns
               .list_type
               .preload(:repository_list_items)
               .each do |column|
      collection << {
        column_id: column.id,
        list_items: column.repository_list_items
                          .limit(Constants::SEARCH_LIMIT)
                          .pluck(:id, :data)
                          .map { |li| [li[0], escape_input(li[1])] }
      }
    end
    collection
  end

  def update_params
    params.permit(repository_row: {}, repository_cells: {}).to_h
  end

  def log_activity(type_of, repository_row)
    Activities::CreateActivityService
      .call(activity_type: type_of,
            owner: current_user,
            subject: @repository,
            team: current_team,
            message_items: {
              repository_row: repository_row.id,
              repository: @repository.id
            })
  end
end
