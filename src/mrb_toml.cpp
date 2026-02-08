#include <mruby.h>
#include <mruby/class.h>
#include <mruby/data.h>
#include <mruby/hash.h>
#include <mruby/array.h>
#include <mruby/string.h>
#include <mruby/time.h>
#include <mruby/presym.h>

#include <toml.hpp>

#include <string>
#include <fstream>
#include <cstring>

#include <mruby/cpp_helpers.hpp>
#include <mruby/num_helpers.hpp>

static void
raise_toml_error(mrb_state* mrb, const std::string& msg)
{
  mrb_raise(mrb, E_RUNTIME_ERROR, msg.c_str());
}

static mrb_value
make_time(mrb_state* mrb, struct RClass* klass, mrb_sym meth,
                int y, int m, int d, int hh, int mm, int ss, int us)
{
  mrb_value args[] = {
    mrb_convert_number(mrb, y),
    mrb_convert_number(mrb, m + 1),
    mrb_convert_number(mrb, d),
    mrb_convert_number(mrb, hh),
    mrb_convert_number(mrb, mm),
    mrb_convert_number(mrb, ss),
    mrb_convert_number(mrb, us)
  };
  return mrb_funcall_argv(mrb, mrb_obj_value(klass), meth, 7, args);
}

/* ========================================================================== */
/* TOML → MRuby                                                               */
/* ========================================================================== */

static mrb_value toml_value_to_mrb(mrb_state* mrb, const toml::value& v);

static mrb_value
toml_array_to_mrb(mrb_state* mrb, const toml::array& arr)
{
  mrb_value a = mrb_ary_new_capa(mrb, arr.size());
  int idx = mrb_gc_arena_save(mrb);
  for (const auto& x : arr) {
    mrb_ary_push(mrb, a, toml_value_to_mrb(mrb, x));
    mrb_gc_arena_restore(mrb, idx);
  }
  return a;
}

static mrb_value
toml_table_to_mrb(mrb_state* mrb, const toml::table& tbl)
{
  mrb_value h = mrb_hash_new_capa(mrb, tbl.size());
  int idx = mrb_gc_arena_save(mrb);
  for (const auto& kv : tbl) {
    const std::string& k = kv.first;
    const toml::value&   v = kv.second;
    mrb_value key = mrb_str_new(mrb, k.data(), k.size());
    mrb_value val = toml_value_to_mrb(mrb, v);
    mrb_hash_set(mrb, h, key, val);
    mrb_gc_arena_restore(mrb, idx);
  }
  return h;
}

template <typename TimeLike>
static void extract_fractional(const TimeLike& t, long& usec)
{
  long total_nsec = 0;

  if (t.nanosecond)  total_nsec += t.nanosecond;
  if (t.microsecond) total_nsec += t.microsecond * 1000;
  if (t.millisecond) total_nsec += t.millisecond * 1'000'000;

  usec = total_nsec / 1000;
}

template <typename DT>
static void dt_to_tm(const DT& dt, struct tm& out);

// ------------------------------------------------------------
// local_datetime: NO UTC conversion. Just copy fields.
// ------------------------------------------------------------
template <>
void dt_to_tm(const toml::local_datetime& dt, struct tm& out)
{
    std::memset(&out, 0, sizeof(out));
    out.tm_year = dt.date.year;
    out.tm_mon  = dt.date.month;
    out.tm_mday = dt.date.day;
    out.tm_hour = dt.time.hour;
    out.tm_min  = dt.time.minute;
    out.tm_sec  = dt.time.second;
    out.tm_isdst = -1;
}

// ------------------------------------------------------------
// offset_datetime: normalize to UTC
// ------------------------------------------------------------
template <>
void dt_to_tm(const toml::offset_datetime& dt, struct tm& out)
{
    struct tm tm_local{};
    tm_local.tm_year = dt.date.year;
    tm_local.tm_mon  = dt.date.month;
    tm_local.tm_mday = dt.date.day;
    tm_local.tm_hour = dt.time.hour;
    tm_local.tm_min  = dt.time.minute;
    tm_local.tm_sec  = dt.time.second;
    tm_local.tm_isdst = -1;

    time_t t = timegm(&tm_local);

    int offset_sec = (dt.offset.hour * 60 + dt.offset.minute) * 60;
    t -= offset_sec;

#if defined(_WIN32)
    gmtime_s(&out, &t);
#else
    gmtime_r(&t, &out);
#endif
}


template <typename DT>
static mrb_value build_datetime(mrb_state* mrb,
                                       struct RClass* klass,
                                       mrb_sym zone,
                                       const DT& dt)
{
  long usec = 0;
  extract_fractional(dt.time, usec);

  struct tm tm_utc{};
  dt_to_tm(dt, tm_utc);

  mrb_value time = make_time(
    mrb, klass, zone,
    tm_utc.tm_year,
    tm_utc.tm_mon,
    tm_utc.tm_mday,
    tm_utc.tm_hour,
    tm_utc.tm_min,
    tm_utc.tm_sec,
    usec
  );

  return time;
}

static mrb_value
toml_datetime_to_mrb(mrb_state* mrb, const toml::value& v)
{
  struct RClass* mod = mrb_module_get_id(mrb, MRB_SYM(TOML));

  if (v.is_local_date()) {
    auto d = v.as_local_date();
    struct RClass* cls = mrb_class_get_under_id(mrb, mod, MRB_SYM(Date));
    return make_time(mrb, cls, MRB_SYM(local),
                           d.year, d.month, d.day,
                           0, 0, 0, 0);
  }

  if (v.is_local_time()) {
    auto t = v.as_local_time();
    struct RClass* cls = mrb_class_get_under_id(mrb, mod, MRB_SYM(Time));

    long usec = 0;
    extract_fractional(t, usec);

    mrb_value time = make_time(
      mrb, cls, MRB_SYM(local),
      1970, 0, 1,
      t.hour, t.minute, t.second,
      usec
    );

    return time;
  }

  if (v.is_local_datetime()) {
    auto dt = v.as_local_datetime();
    struct RClass* cls = mrb_class_get_under_id(mrb, mod, MRB_SYM(DateTime));
    return build_datetime(mrb, cls, MRB_SYM(local), dt);
  }

  if (v.is_offset_datetime()) {
    auto dt = v.as_offset_datetime();
    struct RClass* cls = mrb_class_get_under_id(mrb, mod, MRB_SYM(DateTime));
    return build_datetime(mrb, cls, MRB_SYM(utc), dt);
  }

  raise_toml_error(mrb, "unknown datetime node");
  return mrb_nil_value();
}

static mrb_value
toml_value_to_mrb(mrb_state* mrb, const toml::value& v)
{
  if (v.is_empty()) return mrb_nil_value();
  if (v.is_boolean())  return mrb_bool_value(v.as_boolean());
  if (v.is_integer())  return mrb_convert_number(mrb, v.as_integer());
  if (v.is_floating()) return mrb_convert_number(mrb, v.as_floating());

  if (v.is_string()) {
    const auto& s = v.as_string();
    return mrb_str_new(mrb, s.data(), s.size());
  }

  if (v.is_array()) return toml_array_to_mrb(mrb, v.as_array());
  if (v.is_table()) return toml_table_to_mrb(mrb, v.as_table());

  if (v.is_local_date() || v.is_local_time() ||
      v.is_local_datetime() || v.is_offset_datetime()) {
    return toml_datetime_to_mrb(mrb, v);
  }

  raise_toml_error(mrb, "unknown TOML value type");
  return mrb_nil_value();
}

/* ========================================================================== */
/* MRuby wrapper class (Document)                                             */
/* ========================================================================== */

MRB_CPP_DEFINE_TYPE(toml::value, mrb_toml_value)

static mrb_value
mrb_toml_doc_initialize(mrb_state* mrb, mrb_value self)
{
  mrb_cpp_new<toml::value>(mrb, self);
  return self;
}

static mrb_value
mrb_toml_doc_aref(mrb_state* mrb, mrb_value self)
{
  const char* key;
  mrb_get_args(mrb, "z", &key);

  toml::value* root = mrb_cpp_get<toml::value>(mrb, self);
  if (!root->is_table()) {
    raise_toml_error(mrb, "TOML root is not a table");
  }

  auto& tbl = root->as_table();
  auto it = tbl.find(key);
  if (it == tbl.end()) {
    std::string msg = "missing TOML key: ";
    msg += key;
    raise_toml_error(mrb, msg);
  }

  return toml_value_to_mrb(mrb, it->second);
}

/* ========================================================================== */
/* MRuby → TOML                                                               */
/* ========================================================================== */

static toml::value mrb_to_toml_value(mrb_state* mrb, mrb_value v);

static toml::value
mrb_hash_to_toml_table(mrb_state* mrb, mrb_value obj)
{
  toml::table tbl;
  tbl.reserve(mrb_hash_size(mrb, obj));
  mrb_hash_foreach(mrb, mrb_hash_ptr(obj),
                   [](mrb_state* m, mrb_value k, mrb_value val, void* data) -> int {
                     auto* tbl = static_cast<toml::table*>(data);
                     mrb_value kstr = mrb_obj_as_string(m, k);
                     std::string key(RSTRING_PTR(kstr), RSTRING_LEN(kstr));
                     (*tbl)[key] = mrb_to_toml_value(m, val);
                     return 0;
                   },
                   &tbl);
  return toml::value(tbl);
}

static toml::value
mrb_array_to_toml_array(mrb_state* mrb, mrb_value obj)
{
  mrb_int len = RARRAY_LEN(obj);
  toml::array arr;
  arr.reserve(len);
  for (mrb_int i = 0; i < len; ++i) {
    arr.push_back(mrb_to_toml_value(mrb, mrb_ary_ref(mrb, obj, i)));
  }
  return toml::value(arr);
}

static void
mrb_time_extract(mrb_state* mrb, mrb_value time,
                 struct tm*& out_tm, long& out_usec)
{
  time = mrb_funcall_argv(mrb, time, MRB_SYM(getutc), 0, nullptr);

  out_tm = mrb_time_get_tm(mrb, time);

  mrb_value usec_v = mrb_funcall_argv(mrb, time, MRB_SYM(usec), 0, nullptr);
  out_usec = (long)mrb_integer(usec_v);
}

static toml::offset_datetime
mrb_time_to_offset_datetime(mrb_state* mrb, mrb_value time)
{
  struct tm* tm;
  long usec;
  mrb_time_extract(mrb, time, tm, usec);

  toml::local_date date(
    tm->tm_year + 1900,
    toml::month_t(tm->tm_mon),
    tm->tm_mday
  );

  int millis = (int)(usec / 1000);
  int micros = (int)(usec % 1000);

  toml::local_time tod(
    tm->tm_hour,
    tm->tm_min,
    tm->tm_sec,
    millis,
    micros
  );

  toml::time_offset off(0, 0); // Always UTC

  return toml::offset_datetime(date, tod, off);
}

static toml::value
mrb_to_toml_value(mrb_state* mrb, mrb_value v)
{
  switch (mrb_type(v)) {
    case MRB_TT_TRUE:   return toml::value(true);
    case MRB_TT_FALSE:  return toml::value(false);
    case MRB_TT_INTEGER:return toml::value(mrb_integer(v));
#ifndef MRB_NO_FLOAT
    case MRB_TT_FLOAT:  return toml::value(mrb_float(v));
#endif
    case MRB_TT_STRING: {
      return toml::value(std::string_view(RSTRING_PTR(v), RSTRING_LEN(v)));
    }
    case MRB_TT_HASH:  return mrb_hash_to_toml_table(mrb, v);
    case MRB_TT_ARRAY: return mrb_array_to_toml_array(mrb, v);

    default: {
      struct RClass* core_time_klass =
        mrb_class_get_id(mrb, MRB_SYM(Time));


      if (mrb_obj_is_kind_of(mrb, v, core_time_klass)) {
          toml::value tv(mrb_time_to_offset_datetime(mrb, v));
          return tv;
      }


      mrb_raisef(mrb, E_TYPE_ERROR, "cannot convert %Y to TOML", v);
      return toml::value();
    }
  }
}

/* ========================================================================== */
/* Document dump / load                                                       */
/* ========================================================================== */

static mrb_value
mrb_toml_doc_dump(mrb_state* mrb, mrb_value self)
{
  mrb_value path = mrb_nil_value();
  mrb_get_args(mrb, "|S!", &path);

  toml::value* root = mrb_cpp_get<toml::value>(mrb, self);

  if (mrb_nil_p(path)) {
    std::ostringstream oss;
    oss << *root;

    std::string out = oss.str();
    return mrb_str_new(mrb, out.data(), out.size());
  }

  std::string s(RSTRING_PTR(path), RSTRING_LEN(path));
  std::ofstream ofs(s, std::ios::out | std::ios::trunc);
  if (!ofs) raise_toml_error(mrb, "failed to open file for writing");

  ofs << *root;
  return mrb_nil_value();
}


static mrb_value
mrb_toml_doc_load(mrb_state* mrb, mrb_value self)
{
  mrb_value path;
  mrb_get_args(mrb, "S", &path);

  struct RClass* doc_class =
    mrb_class_get_under_id(mrb, mrb_class_ptr(self), MRB_SYM(Document));
  mrb_value obj = mrb_obj_new(mrb, doc_class, 0, nullptr);

  toml::value* root = mrb_cpp_get<toml::value>(mrb, obj);

  try {
    std::string fname(RSTRING_PTR(path), RSTRING_LEN(path));
    toml::value v = toml::parse(fname);
    if (!v.is_table()) raise_toml_error(mrb, "TOML root must be a table");
    *root = std::move(v);
  }
  catch (const std::exception& e) {
    std::string msg = "TOML parse error: ";
    msg += e.what();
    raise_toml_error(mrb, msg);
  }

  return obj;
}

static mrb_value
mrb_toml_doc_parse(mrb_state* mrb, mrb_value self)
{
  mrb_value doc;
  mrb_get_args(mrb, "S", &doc);

  struct RClass* doc_class =
    mrb_class_get_under_id(mrb, mrb_class_ptr(self), MRB_SYM(Document));
  mrb_value obj = mrb_obj_new(mrb, doc_class, 0, nullptr);

  toml::value* root = mrb_cpp_get<toml::value>(mrb, obj);

  try {
    std::string content(RSTRING_PTR(doc), RSTRING_LEN(doc));
    toml::value v = toml::parse_str(content);
    if (!v.is_table()) raise_toml_error(mrb, "TOML root must be a table");
    *root = std::move(v);
  }
  catch (const std::exception& e) {
    std::string msg = "TOML parse error: ";
    msg += e.what();
    raise_toml_error(mrb, msg);
  }

  return obj;
}

/* ========================================================================== */
/* TOML.dump(obj, path = nil)                                                 */
/* ========================================================================== */

static mrb_value
mrb_toml_module_dump(mrb_state* mrb, mrb_value self)
{
  mrb_value obj;
  mrb_value path = mrb_nil_value();
  mrb_get_args(mrb, "o|S!", &obj, &path);

  // ------------------------------------------------------------
  if (mrb_nil_p(path)) {
    std::ostringstream oss;

    struct RClass* mod = mrb_module_get_id(mrb, MRB_SYM(TOML));
    struct RClass* doc_class =
      mrb_class_get_under_id(mrb, mod, MRB_SYM(Document));

    if (mrb_obj_is_kind_of(mrb, obj, doc_class)) {
      toml::value* root = mrb_cpp_get<toml::value>(mrb, obj);
      oss << *root;
    }
    else if (mrb_type(obj) == MRB_TT_HASH) {
      toml::value v = mrb_hash_to_toml_table(mrb, obj);
      oss << v;
    }
    else {
      toml::value v = mrb_to_toml_value(mrb, obj);
      oss << v;
    }

    std::string out = oss.str();
    return mrb_str_new(mrb, out.data(), out.size());
  }

  std::string s(RSTRING_PTR(path), RSTRING_LEN(path));
  std::ofstream ofs(s, std::ios::out | std::ios::trunc);
  if (!ofs) raise_toml_error(mrb, "failed to open file for writing");

  struct RClass* mod = mrb_module_get_id(mrb, MRB_SYM(TOML));
  struct RClass* doc_class =
    mrb_class_get_under_id(mrb, mod, MRB_SYM(Document));

  if (mrb_obj_is_kind_of(mrb, obj, doc_class)) {
    toml::value* root = mrb_cpp_get<toml::value>(mrb, obj);
    ofs << *root;
  }
  else if (mrb_type(obj) == MRB_TT_HASH) {
    toml::value v = mrb_hash_to_toml_table(mrb, obj);
    ofs << v;
  }
  else {
    toml::value v = mrb_to_toml_value(mrb, obj);
    ofs << v;
  }

  return mrb_nil_value();
}


/* ========================================================================== */
/* Init                                                                       */
/* ========================================================================== */

MRB_BEGIN_DECL
void
mrb_mruby_toml_gem_init(mrb_state* mrb)
{
  struct RClass* mod = mrb_define_module_id(mrb, MRB_SYM(TOML));

  struct RClass* doc =
    mrb_define_class_under_id(mrb, mod, MRB_SYM(Document), mrb->object_class);
  MRB_SET_INSTANCE_TT(doc, MRB_TT_DATA);

  struct RClass* time_class = mrb_class_get_id(mrb, MRB_SYM(Time));
  mrb_define_class_under_id(mrb, mod, MRB_SYM(Date), time_class);
  mrb_define_class_under_id(mrb, mod, MRB_SYM(Time), time_class);
  mrb_define_class_under_id(mrb, mod, MRB_SYM(DateTime), time_class);

  mrb_define_method_id(mrb, doc, MRB_SYM(initialize),
                       mrb_toml_doc_initialize, MRB_ARGS_NONE());
  mrb_define_method_id(mrb, doc, MRB_OPSYM(aref),
                       mrb_toml_doc_aref, MRB_ARGS_REQ(1));
  mrb_define_method_id(mrb, doc, MRB_SYM(dump),
                       mrb_toml_doc_dump, MRB_ARGS_REQ(1));

  mrb_define_class_method_id(mrb, mod, MRB_SYM(load),
                             mrb_toml_doc_load, MRB_ARGS_OPT(1));
    mrb_define_class_method_id(mrb, mod, MRB_SYM(parse),
    mrb_toml_doc_parse, MRB_ARGS_REQ(1));
  mrb_define_class_method_id(mrb, mod, MRB_SYM(dump),
                             mrb_toml_module_dump, MRB_ARGS_ARG(1, 1));
}

void
mrb_mruby_toml_gem_final(mrb_state*) {}
MRB_END_DECL
