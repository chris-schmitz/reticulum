defmodule Ret.Repo.Migrations.AddEmojiPermission do
  use Ecto.Migration

  def up do
    alter table("hubs") do
      modify(:member_permissions, :integer,
        default:
          %{
            spawn_and_move_media: true,
            spawn_camera: true,
            spawn_drawing: true,
            pin_objects: true,
            spawn_emoji: true
          }
          |> Ret.Hub.member_permissions_to_int()
      )
    end

    execute("UPDATE ret0.hubs SET member_permissions = member_permissions | 16;")
  end

  def down do
    # Probably don't ever want to revert this migration, but in case we do:

    # alter table("hubs") do
    #   modify(:member_permissions, :integer,
    #     default:
    #       %{
    #         spawn_and_move_media: true,
    #         spawn_camera: true,
    #         spawn_drawing: true,
    #         pin_objects: true
    #       }
    #       |> Ret.Hub.member_permissions_to_int()
    #   )
    # end

    # execute("UPDATE ret0.hubs SET member_permissions = member_permissions & ~16;");
  end
end
