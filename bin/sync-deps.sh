#!/usr/bin/env bash

set -e

YARN_INSTALL_ARGS=(--frozen-lockfile --non-interactive --silent --ignore-engines)

cd "$(git rev-parse --show-toplevel)" # Run everything from the root of the git tree to match what we store in GIT_PATHS

if [[ ${HUSKY_GIT_PARAMS+foo} ]]; then  # https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash
  # HUSKY_GIT_PARAMS exists therefore called by husky git hook
  read -ra GIT_PARAMS <<< "${HUSKY_GIT_PARAMS}" # Turn into array
  if [[ ${GIT_PARAMS[0]} == "rebase" || ${GIT_PARAMS[0]} == "amend" ]]; then
    # post-rewrite hook, so check everything
    GIT_COMPARE_PATHS=()
	elif [[ ${GIT_PARAMS[1]} ]]; then
		# post-checkout hook
		read -ra GIT_COMPARE_PATHS <<< "${GIT_PARAMS[@]:0:2}"
	else
		# post-merge hook
		GIT_COMPARE_PATHS=(ORIG_HEAD HEAD)
	fi
fi

if [[ "${GIT_COMPARE_PATHS[*]}" ]]; then
  # Sync modified files
  SELECTIVE_UPDATE=1
	GIT_PATHS=$(git diff-tree -r --name-only --no-commit-id "${GIT_COMPARE_PATHS[@]}")
else
	# Sync all files
	GIT_PATHS=$(git ls-tree --full-tree -r --name-only HEAD)
fi

echo "${GIT_PATHS}" | grep "\(^\|/\)yarn.lock$" | while read -r LOCK_PATH; do
	PKG_DIR=$(dirname "${LOCK_PATH}")
	if [[ ${SELECTIVE_UPDATE} ]]; then
		echo "Updating yarn dependencies due to modifed ${LOCK_PATH}"
	else
		if [[ ${PKG_DIR} == "." ]]; then
			echo "Installing root yarn packages"
		else
			echo "Installing ${PKG_DIR} yarn packages"
		fi
	fi
	if [[ -e "${PKG_DIR}/.meteor" ]]; then
		# Due to binary compilation differences, meteor projects need to use its exact node version
		METEOR_NODE=$(cd "${PKG_DIR}" && meteor node -e "process.stdout.write(process.execPath)")
		PATH=$(dirname "${METEOR_NODE}"):$PATH yarn install --cwd "${PKG_DIR}" "${YARN_INSTALL_ARGS[@]}"
	else
		yarn install --cwd "${PKG_DIR}" "${YARN_INSTALL_ARGS[@]}"
	fi
done

echo "${GIT_PATHS}" | grep "\(^\|/\)Pipfile.lock$" | while read -r LOCK_PATH; do
	PKG_DIR=$(dirname "${LOCK_PATH}")
	if [[ ${SELECTIVE_UPDATE} ]]; then
		echo "Updating pipenv dependencies due to modifed ${LOCK_PATH}"
	else
		if [[ ${PKG_DIR} == "." ]]; then
			echo "Installing root pipenv packages"
		else
			echo "Installing ${PKG_DIR} pipenv packages"
		fi
	fi
  PIPFILE_PATH=${LOCK_PATH//Pipfile.lock/Pipfile}
  PY_SHORT_VERSION=$(grep python_version "${PIPFILE_PATH}" | grep -o "[0-9.]\+")
  PY_LATEST_VERSION=$(pyenv install --list | grep "^\s\+${PY_SHORT_VERSION}\.[0-9]\+\$" | grep -o "[0-9.]\+" | tail -n1)
  pyenv install --skip-existing "${PY_LATEST_VERSION}"
  PYENV_PYTHON="$(pyenv prefix "${PY_LATEST_VERSION}")/bin/python"
  PYENV_PY_VERSION_OUTPUT=$("${PYENV_PYTHON}" --version)
  VENV_PY_VERSION_OUTPUT=$(cd "${PKG_DIR}" && "$(pipenv --py)" --version || echo "no venv")
  if [[ "${PYENV_PY_VERSION_OUTPUT}" == "${VENV_PY_VERSION_OUTPUT}" ]]; then
    SYNC_ARGS=()
  else
    SYNC_ARGS=(--python "${PYENV_PYTHON}")
  fi
  (cd "${PKG_DIR}" && PIPENV_VENV_IN_PROJECT=1 pipenv sync --dev "${SYNC_ARGS[@]}")
done
