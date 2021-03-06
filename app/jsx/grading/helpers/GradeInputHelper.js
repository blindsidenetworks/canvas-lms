/*
 * Copyright (C) 2018 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import round from 'compiled/util/round'
import {gradeToScore, scoreToGrade} from '../../gradebook/GradingSchemeHelper'
import numberHelper from '../../shared/helpers/numberHelper'

const MAX_PRECISION = 15 // the maximum precision of a score persisted to the database
const UNGRADED = Object.freeze({enteredAs: null, excused: false, grade: null, score: null})

function precisionOf(value) {
  const parts = value.toString().split('.')
  return parts.length === 2 ? Math.min(parts[1].length, MAX_PRECISION) : 0
}

function roundScore(score, precision = MAX_PRECISION) {
  return round(score, precision)
}

function parseAsGradingScheme(value, options) {
  if (!options.gradingScheme) {
    return null
  }

  const percentage = gradeToScore(value, options.gradingScheme)
  if (percentage == null) {
    return null
  }

  const percent = options.pointsPossible ? percentage : 0

  return {
    enteredAs: 'gradingScheme',
    percent,
    points: options.pointsPossible ? percentage / options.pointsPossible : 0,
    schemeKey: scoreToGrade(percentage, options.gradingScheme)
  }
}

function parseAsPercent(value, options) {
  const percentage = numberHelper.parse(value.replace(/[%％﹪٪]/, ''))
  if (Number.isNaN(percentage)) {
    return null
  }

  let percent = percentage
  let points = roundScore(percentage / 100 * options.pointsPossible, precisionOf(percentage) + 2)

  if (!options.pointsPossible) {
    points = numberHelper.parse(value)
    if (Number.isNaN(points)) {
      percent = 0
      points = 0
    }
  }

  return {
    enteredAs: 'percent',
    percent,
    points,
    schemeKey: scoreToGrade(percent, options.gradingScheme)
  }
}

function parseAsPoints(value, options) {
  const points = numberHelper.parse(value)
  if (Number.isNaN(points)) {
    return null
  }

  const percent = options.pointsPossible ? points / options.pointsPossible * 100 : 0

  return {
    enteredAs: 'points',
    percent: null,
    points,
    schemeKey: scoreToGrade(percent, options.gradingScheme)
  }
}

function parseForGradingScheme(value, options) {
  const result =
    parseAsGradingScheme(value, options) ||
    parseAsPoints(value, options) ||
    parseAsPercent(value, options)

  if (result) {
    return {
      enteredAs: result.enteredAs,
      excused: false,
      grade: result.schemeKey,
      score: result.points
    }
  }

  return UNGRADED
}

function parseForPercent(value, options) {
  const result = parseAsPercent(value, options) || parseAsGradingScheme(value, options)

  if (result) {
    return {
      enteredAs: result.enteredAs,
      excused: false,
      grade: `${result.percent}%`,
      score: result.points
    }
  }

  return UNGRADED
}

function parseForPoints(value, options) {
  const result =
    parseAsPoints(value, options) ||
    parseAsGradingScheme(value, options) ||
    parseAsPercent(value, options)

  if (result) {
    return {
      enteredAs: result.enteredAs,
      excused: false,
      grade: `${result.points}`,
      score: result.points
    }
  }

  return UNGRADED
}

function parseForPassFail(value, options) {
  const cleanValue = value.toLowerCase()
  const result = {...UNGRADED}

  if (cleanValue === 'complete') {
    result.grade = 'complete'
    result.score = options.pointsPossible || 0
    result.enteredAs = 'passFail'
  } else if (cleanValue === 'incomplete') {
    result.grade = 'incomplete'
    result.score = 0
    result.enteredAs = 'passFail'
  }

  return result
}

export function isExcused(grade) {
  return `${grade}`.trim() === 'EX'
}

export function parseTextValue(value, options) {
  const trimmedValue = `${value}`.trim()

  if (trimmedValue === '') {
    return UNGRADED
  }

  if (isExcused(trimmedValue)) {
    return {enteredAs: 'excused', excused: true, grade: null, score: null}
  }

  switch (options.enterGradesAs) {
    case 'gradingScheme': {
      return parseForGradingScheme(trimmedValue, options)
    }
    case 'percent': {
      return parseForPercent(trimmedValue, options)
    }
    case 'passFail': {
      return parseForPassFail(trimmedValue, options)
    }
    default: {
      return parseForPoints(trimmedValue, options)
    }
  }
}
