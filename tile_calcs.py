import math
import itertools

def deg2num(lat_deg, lon_deg, zoom):
  lat_rad = math.radians(lat_deg)
  n = 2.0 ** zoom
  xtile = int((lon_deg + 180.0) / 360.0 * n)
  ytile = int((1.0 - math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi) / 2.0 * n)
  return (xtile, ytile)

def num2deg(xtile, ytile, zoom):
  n = 2.0 ** zoom
  lon_deg = xtile / n * 360.0 - 180.0
  lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * ytile / n)))
  lat_deg = math.degrees(lat_rad)
  return (lat_deg, lon_deg)

def tiles4bounds(min_lat_deg, min_lon_deg, max_lat_deg, max_lon_deg, zoom):

  min_x, max_y = deg2num(min_lat_deg, min_lon_deg, zoom)
  max_x, min_y = deg2num(max_lat_deg, max_lon_deg, zoom)

  x_range = range(min_x, max_x)
  y_range = range(min_y, max_y)

  return itertools.product(x_range, y_range)


def write_tiles(min_lat_deg, min_lon_deg, max_lat_deg, max_lon_deg, zoom):

  all_tiles = list(tiles4bounds(min_lat_deg, min_lon_deg, max_lat_deg, max_lon_deg, zoom))

  file_name = "tiles_{}.csv".format(zoom)
  out_file = open(file_name, 'w')
  for t in all_tiles:
    out_file.write("{},{}\n".format(t[0],t[1]))
 
  out_file.close()
