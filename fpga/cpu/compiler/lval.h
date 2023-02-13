/**
 * value type for lexer
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 15-jun-2020
 * @license see 'LICENSE' file
 */

#ifndef __LR1_LVAL_H__
#define __LR1_LVAL_H__

#include <variant>
#include <optional>
#include <string>
#include <cstdint>


using t_real = float;
using t_int = std::int32_t;
using t_uint = typename std::make_unsigned<t_int>::type;
using t_str = std::string;
using t_byte = std::uint8_t;
using t_bool = t_int;

using t_lval = std::optional<std::variant<t_real, t_int, t_str>>;


#endif
