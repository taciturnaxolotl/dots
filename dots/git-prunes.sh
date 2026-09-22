# shellcheck shell=bash
#
# git-prunes: delete local branches whose upstream branch is gone.
#
# Deleting happens without asking only when the work is provably already in the
# base branch: by ancestry, or as a squash merge, which rewrites the commits and
# so leaves no ancestry for `git branch -d` to find. Everything else is listed
# and left alone, because a vanished remote branch is also what an abandoned
# pull request looks like.

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	echo "git-prunes: not inside a git repository" >&2
	exit 1
fi

dry_run=false
case "${1-}" in
-n | --dry-run) dry_run=true ;;
"") ;;
*)
	echo "usage: git prunes [-n|--dry-run]" >&2
	exit 2
	;;
esac

paint() { gum style --foreground "$1" "${@:2}"; }

gum spin --spinner=dot --show-error --title "Fetching..." -- \
	git fetch --all --prune || exit 1

# origin/HEAD names the branch everything lands in, and git only writes it at
# clone time, so a repo that gained or renamed its default branch since is
# missing it. We just fetched, so asking the remote costs nothing.
git rev-parse --verify --quiet origin/HEAD >/dev/null ||
	git remote set-head origin --auto >/dev/null 2>&1 ||
	true
base=$(git rev-parse --verify --quiet origin/HEAD || git rev-parse --verify HEAD)
base_name=$(git rev-parse --abbrev-ref --verify --quiet origin/HEAD || echo HEAD)

# Replay the branch's tree as one commit on the merge base and ask git cherry
# whether that patch is already upstream; a leading "-" means yes. That is the
# only trace a squash merge leaves behind.
is_squashed() {
	local merge_base tree replay
	merge_base=$(git merge-base "$base" "$1") &&
		tree=$(git rev-parse --verify --quiet "$1^{tree}") &&
		replay=$(git commit-tree "$tree" -p "$merge_base" -m _) || return 1
	[[ $(git cherry "$base" "$replay") == -* ]]
}

here=$(git rev-parse --show-toplevel)
rows=()
while IFS=$'\t' read -r branch sha track worktree; do
	[[ $track == "[gone]" ]] || continue
	if [[ $worktree == "$here" ]]; then
		rows+=(held$'\t'"$branch"$'\t'"$sha"$'\t'"switch away first")
	elif [[ -n $worktree ]]; then
		rows+=(held$'\t'"$branch"$'\t'"$sha"$'\t'"checked out in $worktree")
	elif git merge-base --is-ancestor "$sha" "$base"; then
		rows+=(absorbed$'\t'"$branch"$'\t'"$sha"$'\t'merged)
	elif is_squashed "$sha"; then
		rows+=(absorbed$'\t'"$branch"$'\t'"$sha"$'\t'"squash merged")
	else
		rows+=(orphan$'\t'"$branch"$'\t'"$sha"$'\t'"never landed in $base_name")
	fi
done < <(
	git for-each-ref \
		--format='%(refname:short)%09%(objectname:short)%09%(upstream:track)%09%(worktreepath)' \
		refs/heads
)
((${#rows[@]})) || exit 0

if $dry_run; then
	absorbed_label=$(paint 244 "would delete")
else
	absorbed_label=$(paint 196 deleted)
fi
held_label=$(paint 220 "in use")
orphan_label=$(paint 220 kept)

orphans=()
for row in "${rows[@]}"; do
	IFS=$'\t' read -r verdict branch sha note <<<"$row"
	case $verdict in
	absorbed)
		label=$absorbed_label
		# -d refuses a squash merge, and we have already proven this one safe.
		$dry_run || git branch -D "$branch" >/dev/null
		;;
	held) label=$held_label ;;
	orphan)
		label=$orphan_label
		orphans+=("$branch")
		;;
	esac
	echo " $label $branch $(paint 244 "($sha, $note)")"
done

# Orphans are the only rows that need a decision, so this is the one place worth
# interrupting for.
if ((${#orphans[@]} == 0)) || $dry_run || [[ ! -t 0 ]]; then
	exit 0
fi

echo
picked=$(gum choose --no-limit --height=12 \
	--header="Delete anyway? These commits exist nowhere else." \
	"${orphans[@]}") || exit 0

while IFS= read -r branch; do
	[[ -n $branch ]] || continue
	git branch -D "$branch" >/dev/null
	echo " $(paint 196 deleted) $branch"
done <<<"$picked"
