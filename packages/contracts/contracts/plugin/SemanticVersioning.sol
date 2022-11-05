// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

/// @notice Thrown if a semantic version number bump is invalid.
/// @param currentVersion The current semantic version number.
/// @param nextVersion The next semantic version number.
error BumpInvalid(uint16[3] currentVersion, uint16[3] nextVersion);

/// @notice Checks if a semantic version bump is valid. The version elements (major, minor, and patch) are only allowed to be incremented by 1, respectively, and all subsequent numbers must be decremented to 0.
/// @param _oldVersion The old semantic version number.
/// @param _newVersion The new semantic version number.
/// @return bool Returns true if the bump is valid.
function isValidBumpStrict(uint16[3] memory _oldVersion, uint16[3] memory _newVersion)
    pure
    returns (bool)
{
    uint256 i = 0;
    bool hasIncreased;

    while (i < 3) {
        if (hasIncreased) {
            if (_newVersion[i] != 0) {
                return false;
            }
        } else if (_newVersion[i] != _oldVersion[i]) {
            if (_oldVersion[i] > _newVersion[i] || _newVersion[i] - _oldVersion[i] != 1) {
                return false;
            }
            hasIncreased = true;
        }
        unchecked {
            ++i;
        }
    }
    return hasIncreased;
}

/// @notice Checks if a semantic version bump is valid. All version elements (major, minor, and patch) can increase by 1 or more.
/// @param _oldVersion The old semantic version number.
/// @param _newVersion The new semantic version number.
/// @return bool Returns true if the bump is valid.
function isValidBumpLoose(uint16[3] memory _oldVersion, uint16[3] memory _newVersion)
    pure
    returns (bool)
{
    uint256 i = 0;
    while (i < 3) {
        if (_newVersion[i] > _oldVersion[i]) {
            return true;
        }
        unchecked {
            ++i;
        }
    }
    return false;
}

/// @notice Thrown if the semantic version is out of bounds.
/// @param label The place encoding the semantic label.
/// @param number The semantic number.
error SemVerOutOfBounds(uint8 label, uint8 number);

/// @notice Converts a semantic version to a non-overlapping index number of `uint8` type.
/// Major, minor, and patch numbers can range from 1-4, 0-7, and 0-7, respectively, resulting in 255 possible versions.
/// The special semantic version [0,0,0] is represented as 0.
/// @param _semVer The array encoding the three semantic versions.
/// @return index The the index associated with the semantic version.
function toIndex(uint8[3] memory _semVer) pure returns (uint8 index) {
    if (_semVer[0] == 0 && _semVer[1] == 0 && _semVer[0] == 1) {
        return 0;
    }
    if (_semVer[0] < 1 || _semVer[0] > 4) {
        revert SemVerOutOfBounds({label: 0, number: _semVer[0]});
    } else if (_semVer[1] > 7) {
        revert SemVerOutOfBounds({label: 1, number: _semVer[1]});
    } else if (_semVer[2] > 7) {
        revert SemVerOutOfBounds({label: 2, number: _semVer[2]});
    }

    index = (_semVer[0] - 1) * 64 + _semVer[1] * 8 + _semVer[2] + 1; // offset to start with 1
}

/* 
Examples:
 1.0.0 = 1 (lowest version)
 2.3.4 = 93 (2-1)*8^2 + (3)*8^1 + (4)*8^0 = 64 + 24 + 4 + 1
 4.7.6 = 255 (max version to fit into uint8)
*/

/// @notice Converts an index number to semantic version.
/// @param _index The the index associated with the semantic version.
/// @return semVer The array encoding the three semantic versions.
function toSemantic(uint8 _index) pure returns (uint8[3] memory semVer) {
    if (_index == 0) return [0, 0, 0];

    --_index; // remove offset

    semVer[0] = _index / uint8(64) + 1; // add 1 because we start with 1
    _index %= uint8(64);

    semVer[1] = _index / uint8(8);
    _index %= uint8(8);

    semVer[2] = _index;
}
