class HomeController < ApplicationController
  include ApplicationHelper

  caches_action :index

  def index
    @current_menu = 'home'
  end

  def map
    @current_menu = 'map'
    @landing = false
    @detail_url_fragment = ''
    @current_statistics = []

    @current_dataset_name = ''
    @current_dataset_description = ''
    @current_dataset_slug = ''
    @current_dataset_url = ''
    @current_dataset_provider = ''
    @current_dataset_start_year = Time.now.year
    @current_dataset_end_year = Time.now.year
    @map_colors = GlobalConstants::BLUES

    if params[:dataset_slug].nil?
      @landing = true
      @display_geojson = Rails.cache.fetch('landing_display_geojson') { geography_empty_geojson } 
    
    elsif params[:dataset_slug] == "affordable_resources"
      @map_colors = GlobalConstants::ORANGES
      @detail_url_fragment = "/resources"
      @display_geojson = Rails.cache.fetch('affordable_resources_geojson') { geography_resources_geojson }
      
      @current_dataset_name = 'Affordable resources'
      @current_dataset_description = 'Number of affordable resource locations by Chicago community area.'
      @current_dataset_url = 'http://purplebinder.com/'
      @current_dataset_provider = 'Purple Binder'
      @current_dataset_slug = 'affordable_resources'

      statistics = Geography
                      .select("count(intervention_locations.community_area_id) as resource_cnt")
                      .joins("LEFT JOIN intervention_locations on intervention_locations.community_area_id = geographies.id")
                      .group("geographies.id")
                      .where("geo_type = 'Community Area'").all
      
      statistics.each do |s|
        unless s.resource_cnt.nil?
          @current_statistics << s.resource_cnt.to_i
        end
      end

    else
      @current_dataset = Rails.cache.fetch("#{params[:dataset_slug]}_current_dataset") { Dataset.where("slug = '#{params[:dataset_slug]}'").first }
      @current_dataset_name = @current_dataset.name
      @current_dataset_description = @current_dataset.description
      @current_dataset_slug = @current_dataset.slug
      @current_dataset_url = @current_dataset.url
      @current_dataset_provider = @current_dataset.provider
      @current_dataset_start_year = @current_dataset.start_year
      @current_dataset_end_year = @current_dataset.end_year

      @current_category = Rails.cache.fetch("#{params[:dataset_slug]}_current_category") { Category.find(@current_dataset.category_id) }

      if (@current_category.name == 'Demographics')
        @map_colors = GlobalConstants::REDS
      elsif (@current_category.name.include? 'Uninsured')
        @map_colors = GlobalConstants::GREENS
      elsif (@current_category.name == 'Healthcare Providers')
        @map_colors = GlobalConstants::PURPLES
      end

      statistics = Rails.cache.fetch("#{params[:dataset_slug]}_statistics") { 
                    Statistic.select('value')
                             .joins('INNER JOIN geographies on geographies.id = statistics.geography_id')
                             .where('dataset_id = ?', @current_dataset.id).all }
      
      statistics.each do |s|
        unless s.value.nil? or s.value == 0
          @current_statistics << s.value
        end
      end
      
      @display_geojson = Rails.cache.fetch("#{params[:dataset_slug]}_display_geojson") { geography_geojson(@current_dataset.id) }
    end
    
    @condition_categories = Rails.cache.fetch("condition_categories") { get_categories_by_type('condition') }
    @demographic_categories = Rails.cache.fetch("demographic_categories") { get_categories_by_type('demographic') }
    @uninsured_categories = Rails.cache.fetch("uninsured_categories") { get_categories_like('Uninsured', nil) }
    @hosp_admissions_categories = Rails.cache.fetch("hosp_admission_categories") {get_categories_like(nil,'Hospital Admissions')}

    respond_to do |format|
      format.html # render our template
      format.json { render :json => @display_geojson }
    end

  end

  def partners
    @current_menu = 'partners'
  end

  def about
    @current_menu = 'about'
  end

end
