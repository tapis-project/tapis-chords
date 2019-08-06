class AddSiteTypeToSite < ActiveRecord::Migration[5.1]
  def change
    add_reference :sites, :site_type, index: true, foreign_key: true
  end
end
