class Instrument < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :site

  has_many :vars, dependent: :destroy
  has_many :influxdb_tags, dependent: :destroy

  belongs_to :topic_category

  accepts_nested_attributes_for :vars

  def self.initialize
  end

  def to_s
    name
  end

  def select_label
    "#{site.name}: #{name}"
  end

  def find_var_by_shortname (shortname)
    var_id = Var.all.where("instrument_id='#{self.id}' and shortname='#{shortname}'").pluck(:id)[0]

    if var_id
      return Var.find(var_id)
    else
      return nil
    end
  end

  # Returns the time of first or last measurement given parameter point ("first" or "last")
  def point_time_in_ms(point)
    if point == "last"
      latest_point = GetLastTsPoint.call(TsPoint, 'value', self.id)
    else
      latest_point = GetFirstTsPoint.call(TsPoint, 'value', self.id)
    end

    if(defined? latest_point.to_a.first['time'])
      latest_time_ms = Time.parse(latest_point.to_a.first['time'])
    else
      latest_time_ms = "None"
    end

    return latest_time_ms
  end

  def maximum_plot_points
    time_offset_seconds = eval("#{self.plot_offset_value}.#{self.plot_offset_units}")
    points_to_plot = time_offset_seconds / self.sample_rate_seconds

    return points_to_plot.to_i
  end

  def self.to_csv(options = {})
    CSV.generate(options) do |csv|
      csv << column_names

      all.each do |rails_model|
        csv << rails_model.attributes.values_at(*column_names)
      end
    end
  end

  def self.data_insert_url
    url = instrument_url()
  end

  def is_receiving_data
    if defined? TsPoint
      return IsTsInstrumentAlive.call(TsPoint, "value", self.id, self.sample_rate_seconds+5)
    else
      return false
    end
  end

  def last_age
    if defined? TsPoint
      return GetLastTsAge.call(TsPoint, "value", self.id)
    else
      return false
    end
  end

  def sample_count(sample_type)
    case sample_type
    when :not_test
      measurement_count
    when :test
      measurement_test_count
    else
      measurement_count + measurement_test_count
    end
  end

  def refresh_rate_ms
    # Limit the chart refresh rate
    if self.sample_rate_seconds >= 1
      refresh_rate_ms = self.sample_rate_seconds*1000
    else
      refresh_rate_ms = 1000
    end

    return refresh_rate_ms
  end

  def influxdb_tags_hash
    influxdb_tags = Hash.new

    self.influxdb_tags.each do |influxdb_tag|
      influxdb_tags[influxdb_tag.name] = influxdb_tag.value
    end

    return influxdb_tags
  end

  def instrument_url
    p = Profile.first
    link = p.domain_name + "/instruments/" + self.id.to_s
    return link
  end

  def current_day_download_link(type)
    '/api/v1/data/' + self.id.to_s + ".#{type.to_s}"
  end
end
