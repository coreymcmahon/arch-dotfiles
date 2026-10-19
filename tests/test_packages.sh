#!/usr/bin/env bash
# Package inventory sanity checks.
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
source "$REPO_DIR/lib/common.sh"

official_lists=("$REPO_DIR"/packages/{system,desktop,development,optional,gpu-amd,gpu-intel,gpu-nvidia,gpu-virtual}.txt)
aur_list="$REPO_DIR/packages/aur.txt"

test_lists_parse_and_are_nonempty() {
  local f n
  for f in "${official_lists[@]}" "$aur_list" "$REPO_DIR/packages/stow.txt"; do
    assert_file "$f"
    n=$(read_package_list "$f" | wc -l | tr -d ' ')
    [[ "$n" -gt 0 ]] || fail "$f is empty"
  done
}

test_comments_and_inline_names_are_handled() {
  local tmp="$SANDBOX/list.txt"
  printf '# comment\n  foo bar # trailing\n\nbaz\n' >"$tmp"
  assert_eq $'foo\nbar\nbaz' "$(read_package_list "$tmp")"
}

test_package_names_are_valid() {
  local bad
  bad=$(read_package_list "${official_lists[@]}" "$aur_list" | grep -vE '^[a-z0-9][a-z0-9@._+-]*$' || true)
  assert_eq "" "$bad" "invalid package names"
}

test_no_duplicate_packages() {
  # gpu-*.txt deliberately overlap (mesa); everything else must be unique.
  local dups f
  dups=$(for f in "${official_lists[@]}" "$aur_list"; do
           [[ "$f" == */gpu-* ]] || awk '{ sub(/#.*/, ""); for (i = 1; i <= NF; i++) print $i }' "$f"
         done | sort | uniq -d)
  assert_eq "" "$dups" "duplicate packages across inventories"
}

test_read_package_list_deduplicates_across_files() {
  assert_eq "1" "$(read_package_list "$REPO_DIR"/packages/gpu-amd.txt "$REPO_DIR"/packages/gpu-virtual.txt | grep -c '^mesa$' | tr -d ' ')"
}

test_walker_listed_exactly_once_as_bin() {
  local n
  n=$(read_package_list "${official_lists[@]}" "$aur_list" | grep -c '^walker' || true)
  assert_eq 1 "$n" "walker entries"
  assert_eq walker-bin "$(read_package_list "$aur_list" | grep '^walker')"
}

test_known_renamed_packages_absent() {
  # Packages that no longer exist in the official repos (checked 2026-10-19).
  local p all
  all=$(read_package_list "${official_lists[@]}" "$aur_list")
  for p in ttf-font-awesome hyprland-qtutils libva-mesa-driver nvidia-dkms impala; do
    assert_not_contains $'\n'"$all"$'\n' $'\n'"$p"$'\n' "obsolete package $p"
  done
}

test_stow_groups_exist_in_repo() {
  local g
  while read -r g; do
    [[ -d "$REPO_DIR/$g" ]] || fail "stow group '$g' has no directory"
  done < <(read_package_list "$REPO_DIR/packages/stow.txt")
  _pass=$((_pass + 1))
}

test_configs_reference_installed_tools() {
  # Programs launched by the configs must appear in some inventory (or be shipped
  # with a listed package: nmtui->networkmanager, wpctl->wireplumber, hyprctl->hyprland).
  local all tool
  all=$(read_package_list "${official_lists[@]}" "$aur_list")
  for tool in ghostty dolphin walker waybar hypridle hyprpaper hyprlock hyprsunset hyprshot hyprpicker hyprshutdown swayosd mako greetd udiskie gnome-keyring nwg-look brightnessctl playerctl btop blueberry wiremix pamixer; do
    assert_contains $'\n'"$all"$'\n' $'\n'"$tool" "config references $tool"
  done
}

run_tests
report
