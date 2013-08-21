require 'provision/image/catalogue'
require 'provision/image/commands'

define "grow" do
  extend Provision::Image::Commands

  run("grow the partition table and filesystem") {
    #FILE
    if true
     @whole_device = "/dev/#{spec[:loop0]}"
     @partition = "/dev/mapper/#{spec[:loop0]}p1"
     cmd "cp #{spec[:images_dir]}/gold/generic.img #{spec[:image_path]}"
     cmd "losetup #{@whole_device} #{spec[:image_path]}"
     cmd "qemu-img resize #{spec[:image_path]} #{spec[:image_size]}"
     cmd "losetup -c #{@whole_device}"
    end

    #LVM
    ## CREATE THE LV, blow up if already exists
    ##

    if false
      #error if lv exists
      #create lv
     @whole_device = "/dev/mapper/#{spec[:hostname]}"
     @partition = "#{@whole_device}p1"
    end

    cmd "dd if=#{spec[:images_dir]}/gold/generic.img of=#{@whole_device}"
    cmd "parted -s #{@whole_device} rm 1"
    cmd "parted -s #{@whole_device} mkpart primary ext3 2048s 100%"
    cmd "kpartx -a #{@whole_device}"
    cmd "e2fsck -f -p #{@partition}"
    cmd "resize2fs #{@partition}"
    cmd "kpartx -d #{@whole_device}"
  }

  cleanup {
    cmd "kpartx -d #{@whole_device}"

    if true
      cmd "losetup -d /dev/#{spec[:loop0]}"
    end
  }
end
