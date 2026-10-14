-- Calvary Charismatic Centre branches and their Google Maps listings.
-- Run after schema.sql. This list drives both the branch picker (sign up)
-- and the Church tab, which shows each branch's Google Maps details.
--
-- Afterwards, rename, add or remove branches in Table Editor -> branches;
-- members and sermons point at a branch by its id, so renaming is safe.
-- To add a branch, copy its Place ID from Google's Place ID Finder
-- (https://developers.google.com/maps/documentation/places/web-service/place-id)
-- into google_place_id. Re-running this file only adds listings that are
-- missing.
insert into public.branches (name, google_place_id) values
  ('Calvary Charismatic Center', 'ChIJMSQZzEGR3w8REhpnx7u0krs'),
  ('Calvary Charismatic Center Elshadai Temple, Adenta', 'ChIJ-QL8Uwad3w8RGYsjcDRX9A0'),
  ('Calvary Charismatic Center(CCC) Adom Last Stop - Nungua', 'ChIJTTtwpbKF3w8RwpeKYnQgbxw'),
  ('Calvary Charismatic Center, Sunyani', 'ChIJSSjACzXP2g8RYsZs0hcuHN0'),
  ('Calvary Charismatic Centre', 'ChIJBapKBZOE3w8RWBD4K12LqIQ'),
  ('Calvary Charismatic Centre (Headquarters)', 'ChIJs4nyylGU2w8R7q7U4rvJDBc'),
  ('Calvary Charismatic Centre Agona Swedru Branch', 'ChIJv8ESagJP3g8RKqsPspiXzV8'),
  ('CALVARY CHARISMATIC CENTRE(CCC) Afienya', 'ChIJw5JB2xiBIBARxXa3I4Ssqkc'),
  ('Calvary Charismatic Centre, Klagon', 'ChIJLWY4QACB3w8RtG4ZJ-ONxMA'),
  ('CCC Afienya -Calvary Charismatic Centre', 'ChIJecVDgnmAIBAR29MHWXdFo5M'),
  ('CCC Apenkwa', 'ChIJaRk1M3GZ3w8RFQqwDHgqlLI'),
  ('CCC Botwe', 'ChIJ_wFQ2IyD3w8RIZKp9gPP4AQ'),
  ('CCC Brofoyedu (Calvary Charismatic Centre)', 'ChIJmatFMLOR2w8RML8O16WRtrA'),
  ('CCC Dansoman (Calvary Charismatic Centre)', 'ChIJAQAAAHSX3w8RLFGANOcJ338'),
  ('CCC Sakumono (Calvary Charismatic Centre)', 'ChIJ8QQa75mG3w8RpKuBUPh3abM'),
  ('CCC Westland (Calvary Charismatic Center)', 'ChIJ94FHnfab3w8RUxKGEKJAIkY')
on conflict (google_place_id) do nothing;
